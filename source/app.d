import std.stdio;

import args;

static struct CMDargs {
	@Arg("The source file to be converted", 's', Optional.no) string source;
	@Arg("Texture size in both direction, default is 256", 't') int texSize;
	@Arg("Output file name, otherwise matching filename will be used.", 'o') string output;
	@Arg("Output file type, default is binary.", 'p') string outputType;
	@Arg("File format for the textures, default is TGA.", 'f') string fFormat;
	@Arg("Graphical format of the textures, default is 8 bit grayscale.", 'g') string gFormat;
}
void main(string[] args) {
	writeln("BMFontconv by Laszlo Szeremi.");
	writeln("Converts old bitmap fonts into the newer AngelCode BMFont format.");
	CMDargs opts;
	parseArgs(opts, args);

}
