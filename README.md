# sumgen
command line sumtype generator, using [bettersum](https://github.com/dewf/bettersum)

sumgen reads sumtype definitions directly from your .d source files, and injects the generated code at the end of the source file.

enjoy IDE support, no compile-time mixin overhead, etc.

## directions:

In your source files, format your sumtypes like this:
```d
// !sumgen
enum ThingDef = q{
Thing {
    One,
    Two,
    Three(string s)
}};
```
(note, the name of the enum doesn't matter - but be sure it doesn't conflict with the name of your sumtype directly!)

Then run:

```
dub run sumgen -- /path/to/your/source/root
```

And it will visit every single .d file in your project, writing the definitions to the end of the file (overwriting any definitions already there, or deleting the definitions if you have removed / commented out a sumtype)

In the future, perhaps finer control over the .d files visited will be possible.
