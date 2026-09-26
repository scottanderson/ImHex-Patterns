#pragma author Scott Anderson
#pragma description Battle.net Icons (BNI)

#pragma filename *.bni
#pragma endian little

import std.core;
import std.io;
import std.mem;
import std.string;

#define TGA_USE_LIB
#include <tga.hexpat>

// BNI files hold the chat icons used by classic Battle.net clients
// downloaded from the server over BNFTP. Every icon is stacked vertically
// in a single run-length encoded, 24-bit Truevision TGA image.

// Battle.net user flags; an icon is shown for users with any of these set
bitfield UserFlags {
    blizzardRepresentative : 1;
    channelOperator        : 1;
    speaker                : 1;
    administrator          : 1;
    noUdp                  : 1;
    squelched              : 1;
    specialGuest           : 1;
    unknown                : 25;
};

// Product codes are DWORDs, so the characters are stored reversed ("1H3W" is W3H1)
struct Product {
    char code[4];
} [[sealed, static, format("format_product")]];

fn format_product(ref Product product) {
    return std::string::reverse(product.code);
};

struct Icon {
    UserFlags flags;
    u32 width;
    u32 height;
    Product products[while(std::mem::read_unsigned($, 4) != 0)];
    u32 productsEnd;
} [[format("format_icon")]];

fn format_icon(ref Icon icon) {
    str result = std::format("{}x{}", icon.width, icon.height);
    for (u32 i = 0, i < std::core::member_count(icon.products), i += 1)
        result += " " + format_product(icon.products[i]);
    u32 flags = std::mem::read_unsigned(addressof(icon.flags), 4);
    if (flags != 0)
        result += std::format(" flags=0x{:X}", flags);
    return result;
};

struct BNIHeader {
    // 0x10 in files from Battle.net; BNUBot wrote the size of everything before the image
    u32 headerSize;
    u16 version;
    u16 reserved;
    u32 numIcons;
    // Absolute offset of the image; 0xFFFFFFFF when it directly follows the icons
    u32 dataOffset;
};

struct BNI {
    BNIHeader header;
    Icon icons[header.numIcons];

    u128 imageAddress = header.dataOffset == 0xFFFFFFFF ? $ : header.dataOffset;

    // The image runs to the end of the file
    TGA tga @ imageAddress;
} [[hex::visualize("image", tga)]];

BNI bni @ 0x00;
