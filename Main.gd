extends Control

const CONFIG_PATH = "user://config.cfg"

@onready var file_dialog: FileDialog = %FileDialog
@onready var accept_dialog: AcceptDialog = %AcceptDialog
@onready var file_tree: Tree = %FileTree

@onready var item_containers := [%Constructors, %Operators, %Methods, %Members, %Signals, %Constants, %ThemeItems, %Annotations]

var godot_path: String

var current_file: String
var doc_data: DocData

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
	var dir := DirAccess.open(path)
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
	
	add_files(godot_path.path_join("doc/classes"))
	add_files(godot_path.path_join("modules"))
	add_files(godot_path.path_join("platform"))

func add_files(directory: String):
	var root: TreeItem
	
	var dir := DirAccess.open(directory)
	
	if directory.get_file().contains("classes"):
		for file in dir.get_files():
			if file.get_extension() != "xml":
				continue
			
			if not root:
				root = file_tree.get_root().create_child()
				root.set_text(0, directory.get_base_dir().get_file())
				root.set_selectable(0, false)
			
			var path := dir.get_current_dir().path_join(file)
			var item := root.create_child()
			item.set_text(0, file)
			item.set_metadata(0, path)
			
			get_file_progress(path, item)
	
	for dir2 in dir.get_directories():
		add_files(dir.get_current_dir().path_join(dir2))

func doc_selected() -> void:
	save_current()
	
	var file := file_tree.get_selected().get_metadata(0) as String
	if file.is_empty():
		return
	
	current_file = file
	doc_data = DocData.new()
	doc_data.parse_file(current_file)
	
	%Contentainer.show()
	
	%Title.text = doc_data.top_member.get_name()
	%Description.set_member(doc_data.top_member)
	%BriefDescription.set_member(doc_data.top_member, &"brief_description")
	
	for container in item_containers:
		for child in container.get_children():
			child.free()
	
	for member in doc_data.members:
		match member.type:
			DocData.Member.Type.MEMBER:
				if "overrides" in member.attributes:
					continue
				add_member(member, %Members)
			DocData.Member.Type.METHOD:
				add_member(member, %Methods)
			DocData.Member.Type.SIGNAL:
				add_member(member, %Signals)
			DocData.Member.Type.CONSTANT:
				add_member(member, %Constants)
			DocData.Member.Type.THEME_ITEM:
				add_member(member, %ThemeItems)
			DocData.Member.Type.CONSTRUCTOR:
				add_member(member, %Constructors)
			DocData.Member.Type.OPERATOR:
				add_member(member, %Operators)
			DocData.Member.Type.ANNOTATION:
				add_member(member, %Annotations)
	
	for container in item_containers:
		container.visible = container.get_child_count() > 0
		get_container_label(container).visible = container.visible

func get_container_label(container: Node) -> Control:
	return container.get_parent().get_child(container.get_index() - 1)

func add_member(member: DocData.Member, container: Node):
	var item := preload("res://Item.tscn").instantiate()
	item.connect_changed($SaveTimer.start)
	item.set_member(member)
	container.add_child(item)

func save_current() -> void:
	if current_file.is_empty():
		return
	
	var file := FileAccess.open(current_file, FileAccess.WRITE)
	doc_data.store(file)

func goto_next_empty() -> void:
	for container in item_containers:
		for node in container.get_children():
			if node.member.description.is_empty():
				node.edit()
				return

func _exit_tree() -> void:
	save_current()

func validate() -> void:
	var args: PackedStringArray
	args.append(godot_path.path_join("doc").path_join("tools").path_join("make_rst.py"))
	args.append("--dry-run")
	args.append(godot_path.path_join("doc/classes"))
	args.append(godot_path.path_join("modules"))
	
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
				if pre_xml.get_node_name().ends_with("s"): # nice hack
					continue
				
				empty_element = true
			XMLParser.NODE_TEXT:
				if not pre_xml.get_node_data().strip_edges().is_empty():
					empty_element = false
			XMLParser.NODE_ELEMENT_END:
				if pre_xml.get_node_name().ends_with("s"):
					continue
				
				all += 1
				if empty_element:
					empty += 1
	
	if all > 0:
		if empty == 0:
			item.set_custom_color(0, Color.CYAN)
		else:
			item.set_custom_color(0, Color.GREEN.lerp(Color.RED, empty / all))
