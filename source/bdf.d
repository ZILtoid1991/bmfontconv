module bdf;

import rectpack;
import types;

static import bmfont;
import dimage;

import std.stdio;
import std.algorithm.searching;
import std.array;
import std.conv : to;

alias Rect = stbrp_rect;
/** 
 * Parses BDF font files, also contains the necessary logic for exporting to BMFont.
 * In theory, it can be modified to reading only.
 */
public class BDFParser {
	enum Mode {
		init,
		HeaderParse,
		CharParse,
		BitmapParse,
		EndChar,
		EndFont,
	}
	struct CharInfo {
		//int w, h;
		int xOffset, yOffset;
		int xadvance;
		dchar charID;
		ubyte[] bin;
	}
	File src;
	CharInfo[] chars;
	Rect[] rects;
	CharInfo currChar;
	Rect currRect;
	//int bitmapLinesLeft;
	int numChars;
	int mode;
	int size;
	int fontDescent;	///needed for baseline offset conversion

	this (string filename) {
		src = File(filename);
	}
	void parse() {
		foreach (currLine; src.byLine) {
			auto words = split(currLine, " ");
			switch (mode) {
				case Mode.HeaderParse:
					switch (words[0]) {
						case "SIZE":
							size = to!int(words[1]);
							break;
						case "FONT_DESCENT":
							fontDescent = to!int(words[1]);
							break;
						case "FONTBOUNDINGBOX":
							fontDescent = to!int(words[4]);
							break;
						case "ENDPROPERTIES":
							mode = Mode.init;
							break;
						default:
							break;
					}
					break;
				case Mode.CharParse:
					switch (words[0]) {
						case "ENCODING":
							currChar.charID = to!int(words[1]);
							writeln("Parsing character `", currChar.charID, "`");
							break;
						case "BBX":
							currRect.w = to!int(words[1]);
							currRect.h = to!int(words[2]);
							//bitmapLinesLeft = currRect.h;
							currChar.xOffset = to!int(words[3]);
							const int yOffset = to!int(words[4]);
							if (yOffset < 0)
								currChar.yOffset = size - currRect.h + (yOffset - fontDescent);
							else
								currChar.yOffset = size - currRect.h - (yOffset + fontDescent);
							break;
						case "ENDCHAR":
							chars ~= currChar;
							rects ~= currRect;
							mode = Mode.init;
							break;
						case "BITMAP":
							mode = Mode.BitmapParse;
							break;
						default:
							break;
					}
					break;
				case Mode.BitmapParse:
					if (words[0] != "ENDCHAR") {
						ubyte[] s, d;
						if (words.length > 1) {
							foreach (w ; words) {
								s ~= cast(ubyte)to!int(w, 16);
							}
						} else if ((currLine.length & 1) == 0) {
							for (int i ; i < currLine.length ; i+=2) {
								s ~= cast(ubyte)to!int(currLine[i..i+2], 16);
							}
						}
						d.length = currRect.w;
						for (size_t i; i < d.length ; i++) {
							const size_t j = i & 7, k = i>>>3;
							d[i] = ((s[k]>>(7-j)) & 1) ? ubyte.max : ubyte.min;
						}
						currChar.bin ~= d;
					} else {
						chars ~= currChar;
						rects ~= currRect;
						mode = Mode.init;
					}
					break;
				case Mode.EndFont:
					writeln("ERROR! Unknown data found after font data ending!");
					break;
				default:
					switch (words[0]) {
						case "STARTFONT":
							mode = Mode.HeaderParse;
							break;
						case "ENDFONT":
							if (chars.length != numChars) {
								writefln("ERROR! Character number mismatch! Has:%d Needed:%d",chars.length, numChars);
							}
							mode = Mode.EndFont;
							break;
						case "STARTCHAR":
							currChar = CharInfo.init;
							currRect = Rect.init;
							currRect.id = cast(int)chars.length;
							mode = Mode.CharParse;
							break;
						case "CHARS":
							numChars = to!int(words[1]);
							break;
						default:
							break;
					}
					break;
			}
		}
	}
	void convert(string name, int tSize, FormatFlags formatflags) {
		int pageNum, result;
		Rect[] getUnpackedRects(Rect[] src, ref Rect[] output) {
			Rect[] result;
			foreach (Rect key; src) {
				if (!key.was_packed) {
					key.page = pageNum;
					result ~= key;
				} else {
					output ~= key;
				}
			}
			return result;
		}
		stbrp_context rectPackContext;
		stbrp_node[] nodes;
		nodes.length = tSize * 4;
		Rect[] packedRects, unpackedRects = rects;
		do {
			stbrp_init_target(&rectPackContext, tSize, tSize, nodes.ptr, cast(int)nodes.length);
			result = packRects(&rectPackContext, unpackedRects);
			pageNum++;
			unpackedRects = getUnpackedRects(unpackedRects, packedRects);
		} while (!result);
		bmfont.Font outputFont;
		outputFont.info = bmfont.Font.Info(cast(short)size, 0, 0, 100, 1, [0,0,0,0], [0,0], name, 0);
		ubyte[][] pages;
		pages.length = pageNum;
		foreach (ref ubyte[] key; pages) {
			key.length = tSize * tSize;
		}
		void writeToPage(int x, int y, ref ubyte[] p, ubyte v) {
			p[x + (y * tSize)] = v;
		}
		synchronized foreach (Rect key ; packedRects) {
			CharInfo currCh = chars[key.id];
			writeln("Packing character `", currCh.charID, "`");
			outputFont.chars ~= bmfont.Font.Char(currCh.charID, cast(ushort)key.x, cast(ushort)key.y, cast(ushort)key.w, 
					cast(ushort)key.h, cast(short)currCh.xOffset, cast(short)currCh.yOffset, cast(short)currCh.xadvance, 
					cast(ubyte)key.page, bmfont.Channels.all);
			//int i;
			for (int y ; y < key.h ; y++) {
				for (int x ; x < key.w ; x++) {
					writeToPage(key.x + x, key.y + y, pages[key.page], currCh.bin[x + (y * key.w)]);
					//i++;
				}
			}
		}
		IImageData[] finishedPages;
		if (formatflags.TO_Channels_Mono) {
			foreach (page ; pages) {
				IImageData imgDat = new MonochromeImageData!ubyte(page, tSize, tSize, PixelFormat.Grayscale8Bit, 8);
				//imgDat.flipVertical();
				finishedPages ~= imgDat;
			}
		}
		if (formatflags.TextureOut_Targa) {
			foreach (size_t i, IImageData finishedPage ; finishedPages) {
				finishedPage.flipVertical();
				TGA outputImg = new TGA(finishedPage);
				string filename = name ~ "-" ~ to!string(i) ~ ".tga";
				File outputFile = File(filename, "wb");
				outputImg.save(outputFile);
				outputFont.pages ~= filename;
			}
		} else if (formatflags.TextureOut_PNG) {
			foreach (size_t i, IImageData finishedPage ; finishedPages) {
				PNG outputImg = new PNG(finishedPage, null);
				string filename = name ~ "-" ~ to!string(i) ~ ".png";
				File outputFile = File(filename, "wb");
				outputImg.save(outputFile);
				outputFont.pages ~= filename;
			}
		}
		ubyte[] fontBin = outputFont.toBinary;
		File outputFile = File(name ~ ".fnt", "wb");
		outputFile.rawWrite(fontBin);
	}
}