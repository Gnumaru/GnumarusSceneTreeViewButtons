#class_name GnumarusSceneTreeViewButtonsEditorPlugin
@tool
extends EditorPlugin

const EditorPluginHelper: GDScript = preload('res://addons/GnumarusSceneTreeViewButtons/EditorPluginHelper.gd')



#var m_addon_dir: String
var m_helper_inst: RefCounted



func _init() -> void:
	_print("_init()", "\n")



func _enter_tree() -> void:
	_print("_enter_tree()")
	#m_addon_dir = get_script().resource_path.get_base_dir()
	#m_helper_inst = load(m_addon_dir + "/EditorPluginHelper.gd").new()
	m_helper_inst = EditorPluginHelper.new()



func _exit_tree() -> void:
	_print("_exit_tree()")



func _process(p_delta: float) -> void:
	m_helper_inst.update()



func _print(p_after: Variant, p_before: Variant = "") -> void:
	print("%s- GnumarusSceneTreeViewButtonsEditorPlugin: %s" % [p_before, p_after])
