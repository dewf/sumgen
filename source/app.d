import std.stdio;
import bettersum;

import file = std.file;
import std.regex;
import std.algorithm.iteration : filter;
import std.range: array;
import std.format;
import std.string: replace, strip;
import std.uni : toLower;

enum CONSENT_FILE = "./.sumgen-consent";

int main(string[] args)
{
	if (args.length != 2) {
		stderr.writefln("usage: sumgen <project source root>");
		return 2;
	}

	// check for consent file
	if (!file.exists(CONSENT_FILE)) {
		// check to see if user is OK with destructive writing of files
		writeln("\n============================= W A R N I N G ! ===================================");
		writeln("'sumgen' recursively reads all .d files starting at the root directory,");
		writeln("and destructively edits them (appending or removing generated sumtype definitions).");
		writeln("");
		writeln("Obviously you should have your files in source control, and/or backed up.");
		writeln("Do you consent to have your .d files destructively edited?");
		writeln("(Your answer will be remembered, when running from this working directory)");
		writeln("\n\nAllow destructive edits? y/N");

		auto answer = readln().strip().toLower();
		if (answer == "y" || answer == "yes") {
			file.write(CONSENT_FILE, "the presence of this file indicates your consent to allow 'sumgen' to destructively edit your .d files");
			writefln("\n\n[%s] written", CONSENT_FILE);
			// onward!
		} else {
			writeln("sumgen execution aborted (consent failure)");
			return 3;
		}
	}

	writeln("");

	auto splitRegex = regex(r"\n^// ={77}$", "sm"); // consume optional newline at start, so we don't keep adding blank lines
	auto defRegex = regex(r"
		^// \s* !gensum \s+
		^enum \s+ ([A-Za-z_][A-Za-z0-9_]*)def \s* = \s* q\{
		(.*?)
		^\};
		", "isxm");

	foreach (entry; file.dirEntries("./fakeproject", "*.d", file.SpanMode.depth).filter!(e => e.isFile)) {
		writefln("- scanning [%s]", entry.name.replace(r"\", "/"));
		auto content = file.readText(entry.name);

		// destroy old stuff, if it exists
		auto parts = splitter(content, splitRegex).array();
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
		content ~= "// =============================================================================\n";
		content ~= "// == SUMGEN-GENERATED CODE BELOW - ANYTHING ADDED BELOW WILL BE DESTROYED!! ===\n";
		content ~= "// =============================================================================\n";
		content ~= "\n";

		// append definitions to file
		foreach (m; matches) {
			auto spec = format("%s {%s}", m[1], m[2]);
			content ~= sumtype(spec);
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
