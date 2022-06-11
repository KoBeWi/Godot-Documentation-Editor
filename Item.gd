extends Control

func set_item(item: String, description: String):
	if item.is_empty():
		$Label.hide()
	else:
		$Label.text = item
	$Description.text = description
	refresh_color()

func refresh_color():
	modulate = Color.RED if $Description.text.is_empty() else Color.WHITE
