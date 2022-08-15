extends Control

var member

func set_member(m):
	member = m
	$Description.text_changed.connect(update_member)
	set_item(m.name, m.description, m.arguments, m.return_type)

func set_item(item: String, description: String, arguments := [], return_type := ""):
	if item.is_empty():
		%Label.hide()
	else:
		var text := PackedStringArray([item])
		
		if not arguments.is_empty():
			text.append("(")
			
			var subtext: PackedStringArray
			for argument in arguments:
				subtext.append("%s: %s" % argument)
			text.append(", ".join(subtext))
			
			text.append(")")
		
		if not return_type.is_empty():
			text.append(" -> ")
			text.append(return_type)
		
		%Label.text = "".join(text)
	
	$Description.text = description
	refresh_color()
	
	if is_inside_tree(): ## FIXME: this should exist
		await get_tree().create_timer(0.2).timeout
		$Description.text = $Description.text
		$Description.update_minimum_size()
		$Description.update()

func refresh_color():
	modulate = Color.RED if $Description.text.is_empty() else Color.WHITE

func connect_changed(target: Callable):
	$Description.text_changed.connect(target)

func update_member():
	member.description = $Description.text

func edit():
	$Description.grab_focus()
