extends Control

@onready var description: TextEdit = $Description

var member: DocData.Member
var field: StringName

func _ready() -> void:
	if member:
		description.text = "\n".join(member.get(field))
		refresh_color()
	description.text_changed.connect(update_member)

func set_member(m: DocData.Member, f := &"description"):
	member = m
	field = f
	
	var text: PackedStringArray
	text.append("[color=5ac4da]")
	
	if not member is DocData.ClassMember: 
		text.append(member.get_name())
	text.append("[/color]")
	
	if member is DocData.ParameterMember:
		text.append("(")
		
		var subtext: PackedStringArray
		for argument in member.params:
			Color(0.24313725531101, 0.77254903316498, 0.60784316062927).to_html(false)
			subtext.append("[color=889fc8][url=param:{name}]{name}[/url][/color]: [color=3ec59b]{type}[/color]".format(argument.attributes))
		text.append(", ".join(subtext))
		
		text.append(")")
		
		if member is DocData.MethodMember:
			text.append(" -> [color=3ec59b]{type}[/color]".format(member.return_type))
	else:
		if "type" in member.attributes:
			text.append(": [color=3ec59b]{type}[/color]".format(member.attributes))
	
	%Label.text = "".join(text)
	
	if is_node_ready():
		description.text = "\n".join(member.get(field))
		refresh_color()

func refresh_color():
	modulate = Color.RED if description.text.is_empty() else Color.WHITE

func connect_changed(target: Callable):
	description.text_changed.connect(target)

func update_member():
	member.set(field, description.text.split("\n"))

func edit():
	description.grab_focus()

func _on_label_meta_clicked(meta: Variant) -> void:
	if not description.has_focus():
		return
	
	if meta is String:
		if meta.begins_with("param"):
			description.insert_text_at_caret("[param %s]" % meta.get_slice(":", 1))
