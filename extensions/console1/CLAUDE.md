

When discussing approaches and giving examples, prefer using pseudo-code unless instructed otherwise.

You can write pseudo-code like this:

```
for items 
  if condition
    item.property = <something>
```
Write as concisely as possible. Do not use telegraphic-style writing, do not omit articles in sentences: for instance, do not write «Doing x because Z», write «we are doing X because of Z».

When giving explanations, prefer indicating the cause of the need in the sentence first and the consequence after. For instance «because this and that are doing something that would break, we need to first change this and then update this.»

Also, when writing markdown files, do not write words in bold or italic in the markdown. Surrounding paths with backticks is fine. You may use markdown headings but no bold or italic. 

## refactors
When a refactor requires moving or creating files, start by moving/creating all the necessary files in a single bash command, and then proceed to the edits - avoid moving/creating a single file, then editing it, then proceeding to the next file. What matters here is: all the files that need to be moved/created are operated from a single bash or tool call. Any task planning should reflect this.


## trying out changes
- Make sure to format your changes using `zig fmt <file_name>` after doing edits.
- Make sure that your changes can be compiled using `zig build -Dtest=true` unless instructed otherwise. If the build yields errors, use the compiler warnings and errs into account for your fixes.
- whenever you're making assumptions when writing code, use assertions rather than comments to make them explicit.

## test files 
new test files need to be integrated in the project’s entry point: `~/Documents/personnel/Experiments/reaper/zigExt/reaperZigWrap-mapping_panel_ui_stack/src/console1_extension.zig` in the test block at the end of the sheet.

