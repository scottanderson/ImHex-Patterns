#pragma description Truevision TGA/TARGA image

#pragma MIME image/tga
#pragma endian little

import std.mem;

struct ColorMapSpec {
  u16 entryIndex;
  u16 entryLength;
  u8  bpp;
} [[static]];

bitfield ImageDesc {
  alphaDepth       : 4;
  orderRightToLeft : 1;
  orderTopToBottom : 1;
  padding          : 2;
};

struct ImageSpec {
  u16       xOrigin;
  u16       yOrigin;
  u16       width;
  u16       height;
  u8        depth;
  ImageDesc imageDesc;
} [[static]];

enum ColorMapType : u8 {
  None,
  ColorPalette,
};

enum ImageType : u8 {
  NoData,
  UncompressedColorMapped,
  UncompressedRGB,
  UncompressedGreyscale,
  RLEColorMapped = 9,
  RLERGB,
  RLEGreyscale,
  // huffman + delta + rle
  CompressedColorMapped = 32,
  // huffman + delta + rle, 4-pass quadtree-type
  CompressedColorMapped4Pass,
};

fn GetImageDataSize(ImageSpec imSpec) {
  return imSpec.height * imSpec.width * (imSpec.depth / 8);
};

fn GetColorMapDataSize(ColorMapSpec cmSpec) {
  return cmSpec.entryLength * (cmSpec.bpp / 8);
};

u8 bytesPerPixel = 0;
u128 pixelsRemaining = 0;

bitfield RLEPacketHeader {
  count     : 7;
  runLength : 1;
};

struct RLEPacket {
  RLEPacketHeader header;
  if (header.runLength)
    u8 pixel[bytesPerPixel];
  else
    u8 pixels[(header.count + 1) * bytesPerPixel];
  pixelsRemaining -= header.count + 1;
};

struct Header {
  u8           idLength;
  ColorMapType colorMapType;
  ImageType    imageType;
  ColorMapSpec colorMapSpec;
  ImageSpec    imageSpec;
  char         imageId[idLength];

  if (colorMapType == ColorMapType::ColorPalette) {
    u8 colorMapData[GetColorMapDataSize(colorMapSpec)];
  }

  if (imageType == ImageType::RLEColorMapped || imageType == ImageType::RLERGB || imageType == ImageType::RLEGreyscale) {
    bytesPerPixel = (imageSpec.depth + 7) / 8;
    pixelsRemaining = u128(imageSpec.width) * imageSpec.height;
    RLEPacket imageData[while(pixelsRemaining > 0)];
  } else {
    u8 imageData[GetImageDataSize(imageSpec)];
  }
};

// TGA 2.0 extension area
struct ExtensionArea {
  u16  size;
  char authorName[41];
  char authorComments[324];
  u16  month;
  u16  day;
  u16  year;
  u16  hour;
  u16  minute;
  u16  second;
  char jobName[41];
  u16  jobHours;
  u16  jobMinutes;
  u16  jobSeconds;
  char softwareId[41];
  u16  softwareVersion;
  char softwareVersionLetter;
  u32  keyColor;
  u16  pixelAspectNumerator;
  u16  pixelAspectDenominator;
  u16  gammaNumerator;
  u16  gammaDenominator;
  u32  colorCorrectionOffset;
  u32  postageStampOffset;
  u32  scanLineOffset;
  u8   attributesType;
};

// Offsets in the footer are relative to Start, the address of the header
struct Footer<auto Start> {
  u32 extensionOffset;
  u32 developerDirectoryOffset;
  char signature[0x10];
  char dot;
  char zero;

  if (extensionOffset != 0)
    ExtensionArea extension @ Start + extensionOffset;
};

// Only TGA 2.0 files have a footer, which is the last 0x1A bytes before end
fn HasFooterAt(u128 end) {
  if (end < 0x1A)
    return false;
  return std::mem::read_string(end - 0x12, 0x11) == "TRUEVISION-XFILE.";
};

// A TGA image placed at its start, where End is the address just past its last byte
struct TGAEndingAt<auto End> {
  u128 start = $;
  Header header [[inline]];
  Footer<start> footer[HasFooterAt(End) ? 1 : 0] @ End - 0x1A [[inline]];
} [[hex::visualize("image", this)]];

// A TGA image running to the end of the data
using TGA = TGAEndingAt<std::mem::size()>;

// To embed a TGA in another format, include this file with TGA_USE_LIB defined:
//   #define TGA_USE_LIB
//   #include <tga.hexpat>
//   TGA tga @ start;
// or, if the image is followed by other data:
//   TGAEndingAt<end> tga @ start;
#ifndef TGA_USE_LIB
TGA tga @ 0x00 [[inline]];
#endif
