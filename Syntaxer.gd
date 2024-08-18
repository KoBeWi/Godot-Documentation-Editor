extends SyntaxHighlighter

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var line_text := get_line(line)
	var ret: Dictionary
	
	var i := -1
	while true:
		var start := line_text.find("[", i + 1)
		if start == -1:
			break
		
		if start > 0 and line_text[start - 1] != " ":
			i = start
			continue
		
		var end := line_text.find("]", start + 1)
		if end == -1:
			ret[start] = {"color": Color.RED}
			break
		
		ret[start] = {"color": Color.YELLOW}
		ret[end + 1] = {}
		
		i = end
	
	return ret

func get_line(line: int) -> String:
	return get_text_edit().get_line(line)
