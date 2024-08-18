class_name DocData

var top_member: ClassMember
var members: Array[Member]

func parse_file(path: String):
	var xml := XMLParser.new()
	xml.open(path)
	
	while xml.read() == OK:
		if xml.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var new_member: Member
		
		match xml.get_node_name():
			"class":
				new_member = ClassMember.new()
			"member":
				new_member = Member.new()
				new_member.type = Member.Type.MEMBER
			"method":
				new_member = MethodMember.new()
				new_member.type = Member.Type.METHOD
			"signal":
				new_member = ParameterMember.new()
				new_member.type = Member.Type.SIGNAL
			"constant":
				new_member = Member.new()
				new_member.type = Member.Type.CONSTANT
			"theme_item":
				new_member = Member.new()
				new_member.type = Member.Type.THEME_ITEM
			"constructor":
				new_member = MethodMember.new()
				new_member.type = Member.Type.CONSTRUCTOR
			"operator":
				new_member = MethodMember.new()
				new_member.type = Member.Type.OPERATOR
			"annotation":
				new_member = MethodMember.new()
				new_member.type = Member.Type.ANNOTATION
		
		if new_member:
			new_member.initialize(xml)
			
			if new_member is ClassMember:
				top_member = new_member
			else:
				members.append(new_member)

func store(file: FileAccess):
	var indent: int
	file.store_line("<?xml version=\"1.0\" encoding=\"UTF-8\" ?>")
	store_header(file, indent, top_member.get_type_string(), top_member.attributes)
	
	indent += 1
	
	store_header(file, indent, "brief_description")
	store_description(file, indent, top_member.brief_description)
	store_end_header(file, indent, "brief_description")
	
	store_header(file, indent, "description")
	store_description(file, indent, top_member.description)
	store_end_header(file, indent, "description")
	
	store_header(file, indent, "tutorials")
	for tutorial: String in top_member.tutorials:
		store_line(file, indent + 1, "<link title=\"%s\">%s</link>" % [tutorial.xml_escape(true), top_member.tutorials[tutorial].xml_escape()])
	store_end_header(file, indent, "tutorials")
	
	var current_group: String
	for member in members:
		var new_group := member.get_type_string()
		if new_group != current_group:
			indent -= 1
			if current_group.is_empty():
				indent += 1
			else:
				store_end_header(file, indent, current_group + "s")
			
			current_group = new_group
			store_header(file, indent, current_group + "s")
			
			indent += 1
		
		store_member(file, indent, member)
	
	indent -= 1
	if not current_group.is_empty():
		store_end_header(file, indent, current_group + "s")
	
	indent -= 1
	store_end_header(file, indent, top_member.get_type_string())

func store_line(file: FileAccess, indent: int, string: String):
	file.store_line("\t".repeat(indent) + string)

func store_header(file: FileAccess, indent: int, name: String, attributes: Dictionary = {}, closed := false):
	var bits: PackedStringArray
	bits.append("<" + name)
	for attribute: String in attributes:
		bits.append("%s=\"%s\"" % [attribute.xml_escape(true), attributes[attribute].xml_escape(true)])
	
	if closed:
		store_line(file, indent, " ".join(bits) + " />")
	else:
		store_line(file, indent, " ".join(bits) + ">")

func store_end_header(file: FileAccess, indent: int, name: String):
	store_header(file, indent, "/" + name)

func store_member(file: FileAccess, indent: int, member: Member):
	var is_override := "overrides" in member.attributes
	store_header(file, indent, member.get_type_string(), member.attributes, is_override)
	if is_override:
		return
	
	if member is MethodMember:
		indent += 1
		if not member.return_type.is_empty():
			store_header(file, indent, "return", member.return_type, true)
		
		for param in member.params:
			store_header(file, indent, "param", param.attributes, true)
		
		store_header(file, indent, "description")
		store_description(file, indent, member.description)
		store_end_header(file, indent, "description")
		indent -= 1
	elif member is ParameterMember:
		indent += 1
		for param in member.params:
			store_header(file, indent, "param", param.attributes, true)
		
		store_header(file, indent, "description")
		store_description(file, indent, member.description)
		store_end_header(file, indent, "description")
		indent -= 1
	else:
		store_description(file, indent, member.description)
	
	store_end_header(file, indent, member.get_type_string())

func store_description(file: FileAccess, indent: int, text: PackedStringArray):
	if text.is_empty() or (text.size() == 1 and text[0].is_empty()):
		return
	
	for line in text:
		if line.strip_edges().is_empty():
			file.store_line("")
		else:
			store_line(file, indent + 1, line.xml_escape())

class Member:
	enum Type { CLASS, MEMBER, METHOD, SIGNAL, CONSTANT, THEME_ITEM, CONSTRUCTOR, OPERATOR, ANNOTATION }
	
	var type: Type
	var attributes: Dictionary
	var description: PackedStringArray
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
		
		if not "overrides" in attributes:
			description = extract_description(xml, get_type_string())
	
	func get_name() -> String:
		return attributes.get("name", "<unnamed>")
	
	func get_type_string() -> String:
		match type:
			Type.CLASS:
				return "class"
			Type.MEMBER:
				return "member"
			Type.METHOD:
				return "method"
			Type.SIGNAL:
				return "signal"
			Type.CONSTANT:
				return "constant"
			Type.THEME_ITEM:
				return "theme_item"
			Type.CONSTRUCTOR:
				return "constructor"
			Type.OPERATOR:
				return "operator"
			Type.ANNOTATION:
				return "annotation"
		return "unknown"
	
	func get_attributes(xml: XMLParser) -> Dictionary:
		var ret: Dictionary
		
		for i in xml.get_attribute_count():
			ret[xml.get_attribute_name(i)] = xml.get_attribute_value(i)
		
		return ret
	
	func skip_to_next_element(xml: XMLParser, expected := ""):
		xml.read()
		
		while xml.get_node_type() != XMLParser.NODE_ELEMENT:
			if not expected.is_empty() and xml.get_node_type() == XMLParser.NODE_ELEMENT_END and xml.get_node_name() != expected:
				break
			
			xml.read()
	
	func extract_description(xml: XMLParser, node_name := "description") -> PackedStringArray:
		var text: String
		check_node_name(xml, node_name)
		
		xml.read()
		if xml.get_node_type() == XMLParser.NODE_TEXT:
			text = xml.get_node_data()
			xml.read()
		
		check_node_type(xml, XMLParser.NODE_ELEMENT_END)
		
		var ret := text.split("\n")
		if ret.size() <= 2:
			return []
		
		ret = ret.slice(1, ret.size() - 1)
		var indent := "\t".repeat(ret[0].count("\t"))
		for i in ret.size():
			ret[i] = ret[i].trim_prefix(indent)
		
		return ret
	
	func check_node_name(xml: XMLParser, expected: String):
		check_node_type(xml, XMLParser.NODE_ELEMENT)
		var node := xml.get_node_name()
		assert(node == expected, "Wrong node name: %s, expected %s." % [node, expected])
	
	func check_node_type(xml: XMLParser, expected: int):
		var node := xml.get_node_type()
		assert(node == expected, "Wrong node type: %d, expected %d." % [node, expected])
	
	func _to_string() -> String:
		return "[%s] %s\n%s" % [get_type_string(), get_name(), description]

class ClassMember extends Member:
	func _init() -> void:
		type = Type.CLASS
	
	var brief_description: PackedStringArray
	var tutorials: Dictionary
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
		skip_to_next_element(xml)
		
		if xml.get_node_name() == "brief_description":
			brief_description = extract_description(xml, "brief_description")
			skip_to_next_element(xml)
		
		if xml.get_node_name() == "description":
			description = extract_description(xml, "description")
			skip_to_next_element(xml)
		
		if xml.get_node_name() == "tutorials":
			skip_to_next_element(xml, "link")
			
			for i in 1000:
				if xml.get_node_name() != "link":
					break
				
				var link_data := get_attributes(xml)
				xml.read()
				tutorials[link_data.get("title", "")] = xml.get_node_data()
				
				skip_to_next_element(xml, "link")

class ParameterMember extends Member:
	var params: Array[Parameter]
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
		get_parameters(xml)
		description = extract_description(xml)
	
	func get_parameters(xml: XMLParser):
		for i in 1000:
			if xml.get_node_name() == "param":
				var param := Parameter.new()
				param.attributes = get_attributes(xml)
				params.append(param)
			elif xml.get_node_name() == "description":
				break
			
			skip_to_next_element(xml)
	
	class Parameter:
		var attributes: Dictionary

class MethodMember extends ParameterMember:
	var return_type: Dictionary
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
		
		skip_to_next_element(xml)
		if xml.get_node_name() == "return":
			return_type = get_attributes(xml)
			skip_to_next_element(xml)
		
		get_parameters(xml)
		description = extract_description(xml)
