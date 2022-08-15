extends Control

const CONFIG_PATH = "user://config.cfg"

const ONE_LEVEL_GROUPS = ["member", "constant", "theme_item"]
const TWO_LEVEL_GROUPS = ["method", "constructor", "operator", "signal", "annotation"]

@onready var file_dialog: FileDialog = %FileDialog
@onready var accept_dialog: AcceptDialog = %AcceptDialog
@onready var file_tree: Tree = %FileTree

@onready var item_containers := [%Constructors, %Operators, %Methods, %Members, %Signals, %Constants, %ThemeItems]

var godot_path: String

var current_file: String
var data: ClassData
var current_member: ClassData.MemberData
var file_cache: Array[String]

func _ready() -> void:
	%Contentainer.hide()
	%BriefDescription.connect_changed($SaveTimer.start)
	%Description.connect_changed($SaveTimer.start)
	
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		accept_dialog.popup_centered()
	else:
		godot_path = config.get_value("godot", "path")
		refresh_files()

func on_dir_selected(path: String) -> void:
	var dir := Directory.new()
	dir.open(path)
	if dir.dir_exists("doc/classes") and dir.dir_exists("modules"):
		godot_path = path
		var config := ConfigFile.new()
		config.set_value("godot", "path", path)
		config.save(CONFIG_PATH)
		refresh_files()
	else:
		accept_dialog.dialog_text = "Directory invalid. Try again."
		accept_dialog.popup_centered()

func accept_closed() -> void:
	if not accept_dialog.visible:
		file_dialog.popup_centered_ratio()

func refresh_files():
	file_tree.clear()
	file_tree.create_item()
	
	add_files(godot_path.plus_file("doc/classes"))
	add_files(godot_path.plus_file("modules"))

func add_files(directory: String):
	var root: TreeItem
	
	var dir := Directory.new()
	dir.open(directory)
	
	if directory.get_file().contains("classes"):
		for file in dir.get_files():
			if file.get_extension() != "xml":
				continue
			
			if not root:
				root = file_tree.get_root().create_child()
				root.set_text(0, directory.get_base_dir().get_file())
				root.set_selectable(0, false)
			
			var path := dir.get_current_dir().plus_file(file)
			var item := root.create_child()
			item.set_text(0, file)
			item.set_metadata(0, path)
			
			get_file_progress(path, item)
	
	for dir2 in dir.get_directories():
		add_files(dir.get_current_dir().plus_file(dir2))

func doc_selected() -> void:
	save_current()
	
	var file := file_tree.get_selected().get_metadata(0) as String
	if file.is_empty():
		return
	
	current_file = file
	
	var f := File.new()
	f.open(file, File.READ)
	file_cache = Array(f.get_as_text().split("\n"))
	
	data = ClassData.new()
	var xml := XMLParser.new()
	xml.open(file)
	
	var finish_text: String
	var text: PackedStringArray
	var tabs: int
	
	while xml.read() != ERR_FILE_EOF:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				match xml.get_node_name():
					"class":
						data.name = xml.get_attribute_value(0)
					"method", "member", "signal", "constant", "theme_item", "operator", "constructor", "annotation":
						tabs = file_cache[xml.get_current_line()].count("\t") + 1
						var skip: bool
						for i in xml.get_attribute_count():
							if xml.get_attribute_name(i) == "overrides":
								skip = true
								break
						
						if skip:
							continue
						
						current_member = ClassData.MemberData.new()
						current_member.category = xml.get_node_name()
						current_member.name = xml.get_attribute_value(0)
						current_member.line_range.x = xml.get_current_line() + 1
						
						tabs = file_cache[xml.get_current_line()].count("\t")
						if xml.get_node_name() in ONE_LEVEL_GROUPS:
							tabs += 1
						elif xml.get_node_name() in TWO_LEVEL_GROUPS:
							tabs += 2
					"brief_description", "description":
						if current_member:
							current_member.line_range.x = xml.get_current_line() + 1
						else:
							tabs = 2
					"return":
						for i in xml.get_attribute_count():
							if xml.get_attribute_name(i) == "type":
								current_member.return_type = xml.get_attribute_value(i)
					"param":
						var param := ["", ""]
						
						for i in xml.get_attribute_count():
							if xml.get_attribute_name(i) == "name":
								param[0] = xml.get_attribute_value(i)
							elif xml.get_attribute_name(i) == "type":
								param[1] = xml.get_attribute_value(i)
						
						current_member.arguments.append(param)
			XMLParser.NODE_TEXT:
				var node_text := xml.get_node_data().split("\n")
				
				var dedented_text := Array(node_text) as Array[String]
				dedented_text = dedented_text.slice(1, max(dedented_text.size() - 1, 1))
				
				if not dedented_text.is_empty():
					dedented_text = dedented_text.map(func(line: String): return line.trim_prefix("\t".repeat(tabs)))
					text.append("\n".join(PackedStringArray(dedented_text)))
			XMLParser.NODE_ELEMENT_END:
				match xml.get_node_name():
					"brief_description":
						finish_text = "brief_description"
					"description", "member", "theme_item", "constant", "annotation":
						if current_member:
							finish_text = current_member.name
							current_member.line_range.y = xml.get_current_line()
							data.members.append(current_member)
						else:
							finish_text = "description"
		
		if not finish_text.is_empty():
			var final_text := "\n".join(text)
			
			if finish_text == "brief_description":
				data.brief_description = final_text
			elif finish_text == "description":
				data.description = final_text
			else:
				current_member.description = final_text
				current_member.description_tabs = tabs
			
			text.resize(0)
			finish_text = ""
			current_member = null
			tabs = 0
	
	%Contentainer.show()
	
	%Title.text = data.name
	%Description.set_item("", data.description)
	%BriefDescription.set_item("", data.brief_description)
	
	fill_items("constructor", %Constructors)
	fill_items("operator", %Operators)
	fill_items("method", %Methods)
	fill_items("member", %Members)
	fill_items("signal", %Signals)
	fill_items("constant", %Constants)
	fill_items("theme_item", %ThemeItems)
	fill_items("annotation", %Annotations)

func fill_items(category: String, container: Node):
	for child in container.get_children():
		child.queue_free()
	
	var items_in_category := data.members.filter(func(member): return member.category == category)
	var header := container.get_parent().get_child(container.get_index() - 1)
	if items_in_category.is_empty():
		header.hide()
	else:
		header.show()
		
		for member_data in items_in_category:
			var item := preload("res://Item.tscn").instantiate()
			item.connect_changed($SaveTimer.start)
			item.set_member(member_data)
			container.add_child(item)

func save_current() -> void:
	if current_file.is_empty():
		return
	
	var data_to_save := file_cache.duplicate()
	
	for member in data.members:
		if member.description.is_empty():
			continue
		
		var lines := member.description.split("\n")
		var line_count := member.line_range.y - member.line_range.x
		
		for i in line_count:
			if i >= lines.size():
				data_to_save[member.line_range.x + i] = "::"
			elif lines[i].is_empty():
				data_to_save[member.line_range.x + i] = ""
			else:
				lines[i] = lines[i].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
				data_to_save[member.line_range.x + i] = "\t".repeat(member.description_tabs) + lines[i]
		
		for i in lines.size() - line_count:
			data_to_save[member.line_range.y - 1] += "\n" + "\t".repeat(member.description_tabs) + lines[line_count + i]
	
	data_to_save = data_to_save.filter(func(line: String): return line != "::")
	
	var file := File.new()
	file.open(current_file, File.WRITE)
	file.store_string("\n".join(PackedStringArray(data_to_save)))

func goto_next_empty() -> void:
	for container in item_containers:
		for node in container.get_children():
			if node.member.description.is_empty():
				node.edit()
				return

func _exit_tree() -> void:
	save_current()

class ClassData:
	var name: String
	var brief_description: String
	var description: String
	var members: Array[MemberData]
	
	class MemberData:
		var category: String
		var name: String
		var description: String
		var return_type: String
		var arguments: Array[Array]
		var description_tabs: int
		var line_range: Vector2i
		
		func _to_string() -> String:
			return str(category, "/", name)

func validate() -> void:
	var args: PackedStringArray
	args.append(godot_path.plus_file("doc").plus_file("tools").plus_file("make_rst.py"))
	args.append("--dry-run")
	args.append(godot_path.plus_file("doc/classes"))
	args.append(godot_path.plus_file("modules"))
	
	var output: Array
	var ok := OS.execute("python", args, output)
	if ok == OK:
		OS.alert("No errors found.")
	else:
		OS.alert("Errors found. Check console for details.")
		var errors = Array(output[0].split("\n")).map(func(string: String): return string.strip_edges()).slice(1, -2)
		for error in errors:
			printerr(error)
 
func get_file_progress(path: String, item: TreeItem):
	var all: float
	var empty: float
	var empty_element: bool
	
	var pre_xml := XMLParser.new()
	pre_xml.open(path)
	
	while pre_xml.read() != ERR_FILE_EOF:
		match pre_xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				empty_element = true
				all += 1
			XMLParser.NODE_TEXT:
				empty_element = false
			XMLParser.NODE_ELEMENT_END:
				if empty_element:
					empty += 1
	
	if all > 0:
		item.set_custom_color(0, Color.GREEN.lerp(Color.RED, empty / all))
