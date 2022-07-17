# Godot Documentation Editor

Handy tool to edit Godot engine's class reference XML files.

Godot engine uses XML files to store documentation source of its classes. When you want to add a description for some class or methods of that class etc. you edit these XMLs. It's ok when you add something new and want to document it, but when you want to fill missing documentation for already-existing classes, it gets annoying. Hence I created this tool.

![](https://github.com/KoBeWi/Godot-Documentation-Editor/blob/master/Media/Screenshot.png)

The idea is to make navigating and finding missing descriptions easier. The tool is right now very unfinished, most of the features are missing. It's stable though - it correctly opens XML files and saves your changes without breaking anything \o/ (hopefully)

## Current features
- list all available documentation files in a tree structure
- open documentation files and display their content in a more organized way
- highlight empty descriptions in red
- jump to the first empty desctription in a file

## Planned features
- jump to next empty/unfinished file and description
- display file status in the tree using colors
- display number of complete descriptions vs total and missing descriptions in a file
- BBCode highlighting
- buttons for quick inserting of BBCodes (they are not functional yet)
- find (and replace?)
