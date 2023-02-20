module types;

import std.typecons : BitFlags;

enum FormatFlagsEnum {
	TextureOut_Targa	=	1<<0,
	TextureOut_PNG		=	1<<1,
	TO_Channels_Mono	=	1<<8,
	TO_Channels_ARGB	=	1<<9,
	TO_ChPerPage		=	1<<16,
}
alias FormatFlags = BitFlags!FormatFlagsEnum;