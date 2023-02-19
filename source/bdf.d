module bdf;

import bmfont;

import std.stdio;
import std.algorithm.searching;

public class BDFParser {
    enum Mode {
        init,
        HeaderParse,
        CharParse,
        EndChar,
        EndFont,
    }
    struct CharInfo {
        int w, h;
        int xOffset, yOffset;
        int xadvance;
        dchar charID;
        ubyte[] bin;
    }
    File src;
    CharInfo[] chars;
    CharInfo currChar;
    int numChars;
    int mode;

    void parse() {
        foreach (currLine; src.byLine) {
            const string[] words = findSplit(currLine, " ");
            switch (mode) {
                
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
                            currChar.charID = words[1][0];
                            mode = Mode.CharParse;
                            break;
                        default:
                            break;
                    }
                    break;
            }
        }
    }
}