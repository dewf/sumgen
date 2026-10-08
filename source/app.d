import std.stdio;

import file = std.file;
import std.regex;
import std.algorithm.iteration : filter;
import std.range: array;
import std.string: replace, strip;
import std.uni : toLower;

import bettersum.offline;

enum HEADER_LINE = "// == sumgen v0.5 ==============================================================\n";
enum CONSENT_FILE = "./.sumgen-consent";

enum ErrorCode {
	None,
	BadArgs = 2,
	NoConsent = 3,
	ParseError = 4
}

int main(string[] args)
{
	if (args.length != 2) {
		stderr.writefln("usage: sumgen <project source root>");
		return ErrorCode.BadArgs;
	}

	auto scanPath = args[1];

	// check for consent file
	if (!file.exists(CONSENT_FILE)) {
		// check to see if user is OK with destructive writing of files
		writeln("\n============================= W A R N I N G ! ===================================");
		writeln("'sumgen' recursively reads all .d files starting at the specified root directory,");
		writeln("and destructively edits them (appending or removing generated sumtype definitions).");
		writeln("");
		writeln("Obviously you should have your files in source control, and/or backed up.");
		writeln("Do you consent to having your .d files destructively edited?");
		writeln("(Your answer will be remembered, when running from this working directory)");
		writeln("\n\nAllow destructive edits? y/N");

		auto answer = readln().strip().toLower();
		if (answer == "y" || answer == "yes") {
			file.write(CONSENT_FILE, "the presence of this file indicates your consent to allow 'sumgen' to destructively edit your .d files\n");
			writefln("\n\n[%s] written", CONSENT_FILE);
			// onward!
		} else {
			writeln("sumgen execution aborted (consent failure)");
			return ErrorCode.NoConsent;
		}
	}

	writeln("");

	auto headerLineRegex = regex(r"\n?// == sumgen v([0-9.]+)"); // consume optional newline at start, so we don't keep adding blank lines
	auto defRegex = regex(r"
		^// \s* !sumgen \s+
		^enum \s+ \S+ \s* = \s* q\{
		(.*?\}) \s* \} \s* ;
		", "sxm");

	foreach (entry; file.dirEntries(scanPath, "*.d", file.SpanMode.depth).filter!(e => e.isFile)) {
		writefln("- scanning [%s]", entry.name.replace(r"\", "/"));
		auto content = file.readText(entry.name);

		// destroy old stuff, if it exists
		auto parts = splitter(content, headerLineRegex).array();
		content = parts[0];

		// actually look for definitions
		auto matches = matchAll(content, defRegex).array();

		// short circuit if no matches - don't want to spam our header into files that don't need it
		if (matches.length == 0) {
			// ... but we DO want to remove generated content, if it's not used anymore
			if (parts.length > 1) {
				file.write(entry.name, content);
				writefln("   - (deleted old generated code)");
				writeln("");
			}
			continue;
		}

		content ~= "\n";
		content ~= HEADER_LINE;
		content ~= "// ===== GENERATED CODE BELOW - ANYTHING ADDED BELOW WILL BE DESTROYED!! =======\n";
		content ~= "// =============================================================================\n";
		content ~= "\n";

		// append definitions to file
		foreach (m; matches) {
			auto spec = m[1];
			auto result = sumtype(spec);
			if (auto success = result.isSuccess()) {
				content ~= *success;
			} else if (auto error = result.isError()) {
				writeln();
				writeln("### Error in sumtype ###");
				writeln("-----------------------");
				writeln(spec.strip());
				writeln();
				writefln("error [line %d : col %d]: %s", error.loc.line, error.loc.col, error.message);
				writeln();

				return ErrorCode.ParseError;
			}
			static assert(OfflineResult.isExhaustive(q{Success, Error}));
			content ~= "\n";
		}

		content ~= "// =============================================================================\n";
	    content ~= "// ========= DO NOT ADD CODE BELOW (or above) - IT WILL BE DESTROYED !! ========\n";
		content ~= "// =============================================================================\n";

		file.write(entry.name, content);
		writefln("   - wrote %d sumtype definition%s", matches.length, matches.length > 1 ? "s" : "");
		writeln("");
	}

	return 0;
}
