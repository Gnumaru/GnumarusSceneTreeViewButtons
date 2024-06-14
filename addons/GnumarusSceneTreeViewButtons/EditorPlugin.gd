#class_name GnumarusSceneTreeViewButtonsEditorPlugin
@tool
extends EditorPlugin

var maddondir: String
var mhelperisnt: RefCounted


func _init() -> void:
	_print("_init()", "\n")


func _enter_tree() -> void:
	_print("_enter_tree()")
	maddondir = get_script().resource_path.get_base_dir()
	mhelperisnt = load(maddondir + "/EditorPluginHelper.gd").new()


func _exit_tree() -> void:
	_print("_exit_tree()")


func _process(pdelta: float) -> void:
	mhelperisnt.update()


func _print(pafter: Variant, pbefore: Variant = "") -> void:
	print("%s- GnumarusSceneTreeViewButtonsEditorPlugin: %s" % [pbefore, pafter])
