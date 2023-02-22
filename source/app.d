import std.stdio;
import std.path;

import args;

import bdf;
import types;

static struct CMDargs {
	@Arg("The source file to be converted", 's', Optional.no) string source;
	@Arg("Texture size in both direction, default is 256", 't') int texSize = 256;
	@Arg("Output file name without extension, otherwise matching filename will be used.", 'o') string output;
	@Arg("Output file type, default is binary.", 'p') string outputType = "bin";
	@Arg("File format for the textures, default is TGA.", 'f') string fFormat = "tga";
	@Arg("Graphical format of the textures, default is 8 bit grayscale.", 'g') string gFormat = "greyscale";
}
int main(string[] args) {
	writeln("BMFontconv by Laszlo Szeremi.");
	writeln("Converts old bitmap fonts into the newer AngelCode BMFont format.");
	CMDargs opts;
	if (parseArgs(opts, args)) {
		printArgsHelp(opts, "Quick guide:");
	} else {
		FormatFlags ff;
		switch (opts.fFormat) {
			case "tga", "targa":
				ff.TextureOut_Targa = true;
				break;
			case "png":
				ff.TextureOut_PNG = true;
				break;
			default:
				writeln("Fatal error! Unrecognized file format!");
				return 1;
		}
		switch (opts.gFormat) {
			case "greyscale":
				ff.TO_Channels_Mono = true;
				break;
			case "rgba":
				ff.TO_Channels_ARGB = true;
				break;
			default:
				writeln("Fatal error! Unrecognized graphical format!");
				return 1;
		}
		switch (extension(opts.source)) {
			case ".bdf":
				try {
					BDFParser parser = new BDFParser(opts.source);
					parser.parse();
					parser.convert(opts.output ? opts.output : stripExtension(opts.source), opts.texSize, ff);
					writeln("DONE!");
				} catch (Throwable t) {
					writeln(t);
				}
				break;
			default:
				writeln("Fatal error! File extension not recognized!");
				return 1;
		}
	}
	return 0;
}
