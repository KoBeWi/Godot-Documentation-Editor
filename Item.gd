extends Control

var member: DocData.Member

func _ready() -> void:
	$Description.text_changed.connect(update_member)

func set_member(m: DocData.Member, field := &"description"):
	member = m
	
	if not member is DocData.ClassMember: 
		var text := PackedStringArray([member.get_name()])
		%Label.text = "".join(text)
	
	#if not arguments.is_empty():
		#text.append("(")
		#
		#var subtext: PackedStringArray
		#for argument in arguments:
			#subtext.append("%s: %s" % argument)
		#text.append(", ".join(subtext))
		#
		#text.append(")")
	#
	#if not return_type.is_empty():
		#text.append(" -> ")
		#text.append(return_type)
	
	
	$Description.text = "\n".join(member.get(field))
	refresh_color()
	
	if is_inside_tree(): ## FIXME: this should exist
		await get_tree().create_timer(0.2).timeout
		$Description.text = $Description.text
		$Description.update_minimum_size()
		$Description.queue_redraw()

func refresh_color():
	modulate = Color.RED if $Description.text.is_empty() else Color.WHITE

func connect_changed(target: Callable):
	$Description.text_changed.connect(target)

func update_member():
	member.description = $Description.text

func edit():
	$Description.grab_focus()
