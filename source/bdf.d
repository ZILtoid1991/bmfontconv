module bdf;

import rectpack;
import types;

import bmfont;
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
						default:
							break;
					}
					break;
				case Mode.CharParse:
					switch (words[0]) {
						case "ENCODING":
							currChar.charID = to!int(words[1]);
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
						foreach (w ; words) {
							s ~= cast(ubyte)to!int(w, 16);
						}
						d.length = currRect.w;
						for (size_t i; i < d.length ; i++) {
							const size_t j = i & 7, k = i>>3;
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
							mode = Mode.CharParse;
							break;
						default:
							break;
					}
					break;
			}
		}
	}
	void convert(string name, int tW, int tH, FormatFlags formatflags) {

	}
}