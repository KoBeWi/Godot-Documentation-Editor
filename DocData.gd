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
				new_member.type = Member.Type.METHOD
			"constructor":
				new_member = MethodMember.new()
				new_member.type = Member.Type.CONSTRUCTOR
			"operator":
				new_member = MethodMember.new()
				new_member.type = Member.Type.OPERATOR
			"annotation":
				new_member = Member.new()
				new_member.type = Member.Type.ANNOTATION
		
		if new_member:
			new_member.initialize(xml)
			
			if new_member is ClassMember:
				top_member = new_member
			else:
				members.append(new_member)

class Member:
	enum Type { CLASS, MEMBER, METHOD, SIGNAL, CONSTANT, THEME_ITEM, CONSTRUCTOR, OPERATOR, ANNOTATION }
	
	var type: Type
	var attributes: Dictionary
	var description: String
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
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
	
	func skip_to_next_element(xml: XMLParser):
		xml.read()
		
		while xml.get_node_type() != XMLParser.NODE_ELEMENT:
			xml.read()
	
	func extract_description(xml: XMLParser, node_name := "description") -> String:
		var ret: String
		check_node_name(xml, node_name)
		
		xml.read()
		check_node_type(xml, XMLParser.NODE_TEXT)
		ret = xml.get_node_data()
		
		xml.read()
		check_node_type(xml, XMLParser.NODE_ELEMENT_END)
		
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
	
	var brief_description: String
	var tutorials: Dictionary
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
		
		skip_to_next_element(xml)
		brief_description = extract_description(xml, "brief_description")
		
		skip_to_next_element(xml)
		description = extract_description(xml, "description")

class ParameterMember extends Member:
	var params: Array[Parameter]
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
		get_parameters(xml)
		description = extract_description(xml)
	
	func get_parameters(xml: XMLParser):
		for i in 1000:
			if xml.get_node_name() == "param":
				var attrs := get_attributes(xml)
				var param := Parameter.new()
				param.name = attrs.get("name", "<unnamed>")
				param.name = attrs.get("type", "unknown")
			elif xml.get_node_name() == "description":
				break
			
			skip_to_next_element(xml)
	
	class Parameter:
		var name: String
		var type: String

class MethodMember extends ParameterMember:
	var return_type: String
	
	func initialize(xml: XMLParser):
		attributes = get_attributes(xml)
		
		skip_to_next_element(xml)
		check_node_name(xml, "return")
		var attrs := get_attributes(xml)
		return_type = attrs.get("type", "unknown")
		
		skip_to_next_element(xml)
		get_parameters(xml)
		description = extract_description(xml)
