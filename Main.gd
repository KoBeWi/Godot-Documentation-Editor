extends Control

const CONFIG_PATH = "user://config.cfg"

@onready var file_dialog: FileDialog = %FileDialog
@onready var accept_dialog: AcceptDialog = %AcceptDialog
@onready var file_tree: Tree = %FileTree

var godot_path: String

var data: Dictionary
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
			
			var item := root.create_child()
			item.set_text(0, file)
			item.set_metadata(0, dir.get_current_dir().plus_file(file))
	
	for dir2 in dir.get_directories():
		add_files(dir.get_current_dir().plus_file(dir2))

func doc_selected() -> void:
	save_current()
	
	var file := file_tree.get_selected().get_metadata(0) as String
	if file.is_empty():
		return
	
	var f := File.new()
	f.open(file, File.READ)
	file_cache = Array(f.get_as_text().split("\n"))
	
	data.clear()
	var xml := XMLParser.new()
	xml.open(file)
	
	var inside_member: String
	var finish_text: String
	var text: PackedStringArray
	
	while xml.read() != ERR_FILE_EOF:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				match xml.get_node_name():
					"class":
						data.type = xml.get_attribute_value(0)
					"method", "member", "signal", "constant", "theme_item", "operator":
						inside_member = "%s/%s" % [xml.get_node_name(), xml.get_attribute_value(0)]
			XMLParser.NODE_TEXT:
				var node_text := xml.get_node_data().split("\n")
				
				var dedented_text := Array(node_text) as Array[String]
				dedented_text = dedented_text.slice(1, max(dedented_text.size() - 1, 1))
				
				if not dedented_text.is_empty():
					var min_tabs: int = 999
					for line in dedented_text:
						if not line.is_empty():
							min_tabs = min(min_tabs, line.count("\t"))
					
					var prefix := ""
					for i in min_tabs:
						prefix += "\t"
					
					dedented_text = dedented_text.map(func(line: String): return line.trim_prefix(prefix))
					
					text.append("\n".join(PackedStringArray(dedented_text)))
			XMLParser.NODE_ELEMENT_END:
				match xml.get_node_name():
					"brief_description":
						finish_text = "brief_description"
					"description", "member", "theme_item":
						if inside_member.is_empty():
							finish_text = "description"
						else:
							finish_text = inside_member
		
		if not finish_text.is_empty():
			var final_text := "\n".join(text)
			
			if finish_text.get_slice_count("/") == 1:
				data[finish_text] = final_text
			else:
				var category := finish_text.get_slice("/", 0)
				if not category in data:
					data[category] = {}
				
				data[category][finish_text.get_slice("/", 1)] = final_text
			
			text.resize(0)
			finish_text = ""
	
	%Contentainer.show()
	
	%Title.text = data.type
	%Description.set_item("", data.description)
	%BriefDescription.set_item("", data.brief_description)
	
	fill_items("method", %Methods)
	fill_items("member", %Members)
	fill_items("operator", %Operators)
	fill_items("signal", %Signals)
	fill_items("constant", %Constants)
	fill_items("theme_item", %ThemeItems)

func fill_items(category: String, container: Node):
	for child in container.get_children():
		child.queue_free()
	
	var header := container.get_parent().get_child(container.get_index() - 1)
	if data.get(category, {}).is_empty():
		header.hide()
	else:
		header.show()
		
		for item_name in data[category]:
			var item := preload("res://Item.tscn").instantiate()
			item.connect_changed($SaveTimer.start)
			item.set_item(item_name, data[category][item_name])
			container.add_child(item)

func save_current() -> void:
	print("save")
