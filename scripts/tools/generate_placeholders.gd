extends EditorScript

## 生成占位符美术资源的脚本
## 在 Godot 编辑器中运行：编辑器 -> 工具 -> 脚本编辑器 -> 运行脚本
##
## 此脚本会生成 P0 和 P1 优先级的所有占位符资源
## 所有占位符都使用简单但可识别的设计，方便后续替换为正式资源

# ============================================================
#  配置区域
# ============================================================

# 是否生成 P0 资源（核心可玩）
const GEN_P0 = true

# 是否生成 P1 资源（体验完整）
const GEN_P1 = true

# 占位符标识文字颜色
const LABEL_COLOR = Color(1, 1, 1, 0.8)

# ============================================================
#  主函数
# ============================================================

func _run() -> void:
	print("\n")
	print("==========================================")
	print("  占位符美术资源生成器")
	print("==========================================")
	print("")

	var count = 0
	var errors = 0

	# 获取项目根目录
	var project_dir = ProjectSettings.globalize_path("res://")
	print("项目目录: " + project_dir)
	print("")

	# 创建输出目录
	_ensure_dir(project_dir + "assets/textures/backgrounds/")
	_ensure_dir(project_dir + "assets/textures/characters/")
	_ensure_dir(project_dir + "assets/textures/icons/items/")
	_ensure_dir(project_dir + "assets/textures/icons/map/")
	_ensure_dir(project_dir + "assets/textures/icons/materials/")
	_ensure_dir(project_dir + "assets/textures/icons/products/")
	_ensure_dir(project_dir + "assets/textures/ui/")
	_ensure_dir(project_dir + "assets/textures/vfx/")

	# P1 优先级资源
	if GEN_P1:
		print("--- 生成 P1 资源 ---")
		count += _gen_p1_backgrounds(project_dir)
		count += _gen_p1_icons(project_dir)
		count += _gen_p1_ui(project_dir)
		print("")

	# P0 核心资源
	if GEN_P0:
		print("--- 生成 P0 资源 ---")
		count += _gen_p0_materials(project_dir)
		count += _gen_p0_products(project_dir)
		count += _gen_p0_ui(project_dir)
		print("")

	print("==========================================")
	print("  生成完成！")
	print("  成功: %d 个文件" % count)
	print("  失败: %d 个" % errors)
	print("==========================================")
	print("")
	print("【后续步骤】")
	print("  1. 在 Godot 编辑器中，右键点击 'assets' 文件夹")
	print("  2. 选择 '重新导入' 来刷新纹理")
	print("  3. 运行游戏测试资源加载")
	print("")

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)

# ============================================================
#  P1 资源生成
# ============================================================

func _gen_p1_backgrounds(project_dir: String) -> int:
	print("[P1] 生成背景资源...")
	var count = 0

	# D1 - 地牢区域地图背景 (1280x720)，不添加文字标签避免显示 "DAYMAP"
	var img1 = _create_bg_image(1280, 720, Color(0.086, 0.075, 0.067), "")
	count += _save_img(img1, project_dir + "assets/textures/backgrounds/daymap_bg.png")

	# E1 - 结局画面背景 (1280x720)
	var img2 = _create_bg_image(1280, 720, Color(0.05, 0.04, 0.08), "ENDING")
	count += _save_img(img2, project_dir + "assets/textures/backgrounds/ending_bg.png")

	print("  ✓ 背景资源生成完成 (%d 个)" % count)
	return count

func _gen_p1_icons(project_dir: String) -> int:
	print("[P1] 生成图标资源...")
	var count = 0

	# D2a-e - 采集点图标 5 个 (64x64)
	var gathering_icons = [
		["icon_mushroom_grotto", "🍄", Color(0.6, 0.4, 0.7)],
		["icon_abandoned_mine", "⛏", Color(0.5, 0.5, 0.5)],
		["icon_underground_river", "💧", Color(0.2, 0.5, 0.9)],
		["icon_grape_terrace", "🍇", Color(0.6, 0.2, 0.8)],
		["icon_underground_farm", "🌾", Color(0.9, 0.8, 0.3)],
	]
	for icon in gathering_icons:
		var img = _create_circle_icon(64, 64, icon[2], icon[1])
		count += _save_img(img, project_dir + "assets/textures/icons/map/" + icon[0] + ".png")

	# C11a-f - 普通客人头像 6 种 (64x64)
	var guest_icons = [
		["guest_dwarf", "🧔", Color(0.6, 0.4, 0.2)],
		["guest_knight", "⚔", Color(0.7, 0.7, 0.8)],
		["guest_rogue", "🗡", Color(0.3, 0.3, 0.4)],
		["guest_wizard", "🔮", Color(0.4, 0.2, 0.7)],
		["guest_merchant", "💰", Color(0.9, 0.8, 0.3)],
		["guest_commoner", "👤", Color(0.7, 0.6, 0.5)],
	]
	for icon in guest_icons:
		var img = _create_circle_icon(64, 64, icon[2], icon[1])
		count += _save_img(img, project_dir + "assets/textures/characters/" + icon[0] + ".png")

	# U1-U5 - 通用小图标 5 个 (24x24)
	var ui_icons = [
		["icon_coin", "💰", Color(1.0, 0.85, 0.0)],
		["icon_time", "⏱", Color(0.8, 0.8, 0.8)],
		["icon_patience", "❤", Color(0.9, 0.2, 0.2)],
		["icon_stamina", "⚡", Color(1.0, 0.8, 0.0)],
		["icon_star", "⭐", Color(1.0, 1.0, 0.0)],
	]
	for icon in ui_icons:
		var img = _create_square_icon(24, 24, icon[2], icon[1])
		count += _save_img(img, project_dir + "assets/textures/ui/" + icon[0] + ".png")

	print("  ✓ 图标资源生成完成 (%d 个)" % count)
	return count

func _gen_p1_ui(project_dir: String) -> int:
	print("[P1] 生成 UI 组件...")
	var count = 0

	# 羊皮纸 9-patch 面板 (32x32)
	var img1 = _create_9patch_image(32, 32, Color(0.18, 0.16, 0.15), Color(0.33, 0.26, 0.20))
	count += _save_img(img1, project_dir + "assets/textures/ui/panel_parchment_9patch.png")

	# 对话气泡 9-patch (32x32)
	var img2 = _create_9patch_image(32, 32, Color(0.2, 0.18, 0.15, 0.95), Color(1.0, 0.74, 0.50))
	count += _save_img(img2, project_dir + "assets/textures/ui/bubble_order_9patch.png")

	# T2 - 标题招牌字 (512x128)
	var img3 = _create_title_sign_image()
	count += _save_img(img3, project_dir + "assets/textures/ui/title_sign.png")

	# T4a-d - 标题装饰元素 4 个
	var decos = [
		["deco_left", "◆", Color(1.0, 0.7, 0.2)],
		["deco_right", "◆", Color(1.0, 0.7, 0.2)],
		["deco_top", "─", Color(1.0, 0.7, 0.2)],
		["deco_bottom", "─", Color(1.0, 0.7, 0.2)],
	]
	for deco in decos:
		var img = _create_deco_image(64, 64, deco[1], deco[2])
		count += _save_img(img, project_dir + "assets/textures/ui/" + deco[0] + ".png")

	# 体力分段槽 (48x32)
	var img4 = _create_bar_image(48, 32, Color(0.29, 0.55, 0.25), Color(0.20, 0.40, 0.18))
	count += _save_img(img4, project_dir + "assets/textures/ui/bar_stamina_segment.png")

	# 分隔线 (1000x4)
	var img5 = _create_divider_image(1000, 4, Color(0.5, 0.35, 0.2))
	count += _save_img(img5, project_dir + "assets/textures/ui/divider_rope.png")

	# 按钮贴图 6 个
	count += _save_img(_create_button_image(200, 48, Color(1.0, 0.74, 0.50), Color(0.8, 0.6, 0.4)), project_dir + "assets/textures/ui/btn_wide_normal.png")
	count += _save_img(_create_button_image(200, 48, Color(1.0, 0.58, 0.0), Color(0.8, 0.5, 0.0)), project_dir + "assets/textures/ui/btn_wide_hover.png")
	count += _save_img(_create_button_image(200, 48, Color(0.8, 0.45, 0.0), Color(0.6, 0.35, 0.0)), project_dir + "assets/textures/ui/btn_wide_pressed.png")
	count += _save_img(_create_button_image(120, 36, Color(1.0, 0.74, 0.50), Color(0.8, 0.6, 0.4)), project_dir + "assets/textures/ui/btn_small_normal.png")
	count += _save_img(_create_button_image(120, 36, Color(1.0, 0.58, 0.0), Color(0.8, 0.5, 0.0)), project_dir + "assets/textures/ui/btn_small_hover.png")
	count += _save_img(_create_button_image(120, 36, Color(0.8, 0.45, 0.0), Color(0.6, 0.35, 0.0)), project_dir + "assets/textures/ui/btn_small_pressed.png")

	# 槽位贴图 3 个
	count += _save_img(_create_slot_image(80, 80, Color(0.14, 0.12, 0.11), Color(0.33, 0.26, 0.20)), project_dir + "assets/textures/ui/slot_material.png")
	count += _save_img(_create_slot_image(80, 80, Color(0.18, 0.16, 0.15), Color(1.0, 0.74, 0.50)), project_dir + "assets/textures/ui/slot_result.png")
	count += _save_img(_create_slot_image(64, 64, Color(0.12, 0.11, 0.10), Color(0.33, 0.26, 0.20)), project_dir + "assets/textures/ui/slot_shortcut.png")

	# 快捷栏/顶栏背景
	count += _save_img(_create_bar_bg_image(1200, 64, Color(0.09, 0.08, 0.07), Color(0.33, 0.26, 0.20)), project_dir + "assets/textures/ui/bar_shortcut_bg.png")
	count += _save_img(_create_bar_bg_image(1280, 48, Color(0.06, 0.05, 0.05), Color(0.33, 0.26, 0.20)), project_dir + "assets/textures/ui/bar_top_panel.png")

	# 耐心条填充
	count += _save_img(_create_bar_image(100, 12, Color(0.29, 0.55, 0.25), Color(0.20, 0.40, 0.18)), project_dir + "assets/textures/ui/bar_patience_fill.png")

	print("  ✓ UI 组件生成完成 (%d 个)" % count)
	return count

# ============================================================
#  P0 资源生成
# ============================================================

func _gen_p0_materials(project_dir: String) -> int:
	print("[P0] 生成材料图标...")
	var count = 0

	var materials = [
		["wheat", "🌾", Color(0.9, 0.8, 0.5)],
		["mushroom", "🍄", Color(0.8, 0.6, 0.7)],
		["herb", "🌿", Color(0.4, 0.7, 0.3)],
		["grape", "🍇", Color(0.6, 0.2, 0.8)],
		["milk", "🥛", Color(0.95, 0.95, 0.9)],
		["cream", "🫗", Color(1.0, 0.95, 0.85)],
		["honey", "🍯", Color(1.0, 0.8, 0.2)],
		["yeast", "🧫", Color(0.8, 0.7, 0.6)],
	]
	for mat in materials:
		var img = _create_circle_icon(48, 48, mat[2], mat[1])
		count += _save_img(img, project_dir + "assets/textures/icons/materials/" + mat[0] + ".png")

	print("  ✓ 材料图标生成完成 (%d 个)" % count)
	return count

func _gen_p0_products(project_dir: String) -> int:
	print("[P0] 生成成品图标...")
	var count = 0

	var products = [
		["bread", "🍞", Color(0.85, 0.65, 0.4)],
		["ale", "🍺", Color(0.9, 0.7, 0.3)],
		["wine", "🍷", Color(0.6, 0.1, 0.3)],
		["cheese", "🧀", Color(1.0, 0.85, 0.4)],
		["roast", "🥩", Color(0.7, 0.3, 0.2)],
		["stew", "🍲", Color(0.6, 0.4, 0.3)],
		["pie", "🥧", Color(0.8, 0.6, 0.4)],
		["salad", "🥗", Color(0.5, 0.8, 0.3)],
		["honey_bread", "🍯🍞", Color(0.9, 0.7, 0.3)],
		["premium_ale", "🍺✨", Color(1.0, 0.8, 0.2)],
	]
	for prod in products:
		var img = _create_circle_icon(48, 48, prod[2], prod[1])
		count += _save_img(img, project_dir + "assets/textures/icons/products/" + prod[0] + ".png")

	print("  ✓ 成品图标生成完成 (%d 个)" % count)
	return count

func _gen_p0_ui(project_dir: String) -> int:
	print("[P0] 生成基础 UI...")
	# P0 的基础 UI 已在 _gen_p1_ui 中生成
	print("  ✓ 基础 UI 已在 P1 中生成")
	return 0

# ============================================================
#  图像创建辅助函数
# ============================================================

## 创建背景图像
func _create_bg_image(w: int, h: int, bg_color: Color, label: String) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg_color)

	# 添加网格线（模拟地图）
	if label == "DAYMAP":
		var line_color = bg_color.lightened(0.05)
		for y in range(0, h, 80):
			for x in range(w):
				img.set_pixel(x, y, line_color)
		for x in range(0, w, 80):
			for y in range(h):
				img.set_pixel(x, y, line_color)

	# 添加标签（空字符串时不添加，避免英文占位文字）
	if label != "":
		_add_label(img, w, h, label)

	return img

## 创建圆形图标
func _create_circle_icon(w: int, h: int, bg_color: Color, emoji: String) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var center_x = w / 2
	var center_y = h / 2
	var radius = min(w, h) / 2 - 2

	# 绘制圆形
	for y in range(h):
		for x in range(w):
			var dx = x - center_x
			var dy = y - center_y
			var dist = sqrt(dx*dx + dy*dy)
			if dist <= radius:
				img.set_pixel(x, y, bg_color)

	# 添加边框
	for y in range(h):
		for x in range(w):
			var dx = x - center_x
			var dy = y - center_y
			var dist = sqrt(dx*dx + dy*dy)
			if dist > radius - 2 and dist <= radius:
				img.set_pixel(x, y, bg_color.darkened(0.3))

	# 添加标签
	var label = emoji.substr(0, min(emoji.length(), 2))
	_add_label(img, w, h, label)

	return img

## 创建方形图标
func _create_square_icon(w: int, h: int, bg_color: Color, emoji: String) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	# 绘制圆角方形
	var radius = 4
	for y in range(h):
		for x in range(w):
			var in_rect = (x >= radius and x < w - radius) or (y >= radius and y < h - radius)
			var in_corner = false

			# 检查四个角
			if _is_in_rounded_corner(x, y, radius, radius, radius):
				in_corner = true
			if _is_in_rounded_corner(x, y, w - radius - 1, radius, radius):
				in_corner = true
			if _is_in_rounded_corner(x, y, radius, h - radius - 1, radius):
				in_corner = true
			if _is_in_rounded_corner(x, y, w - radius - 1, h - radius - 1, radius):
				in_corner = true

			if in_rect or in_corner:
				img.set_pixel(x, y, bg_color)

	# 添加标签
	_add_label(img, w, h, emoji.substr(0, 1))

	return img

func _is_in_rounded_corner(x: int, y: int, cx: int, cy: int, r: int) -> bool:
	var dx = x - cx
	var dy = y - cy
	return dx*dx + dy*dy <= r*r

## 创建 9-patch 图像
func _create_9patch_image(w: int, h: int, bg_color: Color, border_color: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg_color)

	# 绘制边框
	for i in range(w):
		img.set_pixel(i, 0, border_color)
		img.set_pixel(i, h-1, border_color)
	for i in range(h):
		img.set_pixel(0, i, border_color)
		img.set_pixel(w-1, i, border_color)

	# 9-patch 标记（中间区域可拉伸）
	var patch_size = 10
	for y in range(patch_size):
		for x in range(patch_size):
			if y < img.get_height() and x < img.get_width():
				img.set_pixel(x, y, bg_color.lightened(0.05))
	for y in range(h-patch_size, h):
		for x in range(w-patch_size, w):
			if y >= 0 and x >= 0:
				img.set_pixel(x, y, bg_color.lightened(0.05))

	return img

## 创建标题招牌
func _create_title_sign_image() -> Image:
	var w = 512
	var h = 128
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	# 木制招牌背景
	var bg_color = Color(0.5, 0.35, 0.2)
	img.fill(bg_color)

	# 添加木纹效果
	for y in range(h):
		for x in range(w):
			var noise = sin(x * 0.1) * 0.03
			if (y + x) % 4 == 0:
				img.set_pixel(x, y, bg_color.lightened(0.03 + noise))
			elif (y + x) % 7 == 0:
				img.set_pixel(x, y, bg_color.darkened(0.03))

	# 添加边框
	var border_color = Color(1.0, 0.74, 0.50)
	for i in range(w):
		img.set_pixel(i, 0, border_color)
		img.set_pixel(i, h-1, border_color)
	for i in range(h):
		img.set_pixel(0, i, border_color)
		img.set_pixel(w-1, i, border_color)

	# 添加文字（不添加英文占位标签，避免与中文标题重叠）
	# _add_label(img, w, h, "TAVERN")  # 已禁用以避免英文占位文字

	return img

## 创建装饰元素
func _create_deco_image(w: int, h: int, shape: String, color: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var center_x = w / 2
	var center_y = h / 2

	if shape == "◆":
		for y in range(h):
			var half_width = int((h/2 - abs(y - center_y)) * 0.8)
			for x in range(center_x - half_width, center_x + half_width):
				if x >= 0 and x < w:
					img.set_pixel(x, y, color)
	elif shape == "─":
		for y in range(center_y - 2, center_y + 3):
			for x in range(w):
				img.set_pixel(x, y, color)

	return img

## 创建进度条/体力条
func _create_bar_image(w: int, h: int, fill_color: Color, border_color: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	for y in range(2, h-2):
		for x in range(2, w-2):
			img.set_pixel(x, y, fill_color)

	# 绘制边框
	for i in range(w):
		img.set_pixel(i, 0, border_color)
		img.set_pixel(i, h-1, border_color)
	for i in range(h):
		img.set_pixel(0, i, border_color)
		img.set_pixel(w-1, i, border_color)

	return img

## 创建分隔线
func _create_divider_image(w: int, h: int, color: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

## 创建按钮贴图
func _create_button_image(w: int, h: int, bg_color: Color, shadow_color: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	# 填充背景
	for y in range(h):
		for x in range(w):
			var t = float(y) / float(h)
			var color = bg_color.lightened(0.1 * (1.0 - t))
			img.set_pixel(x, y, color)

	# 绘制边框
	var border_color = shadow_color
	for i in range(w):
		img.set_pixel(i, 0, border_color)
		img.set_pixel(i, h-1, border_color.darkened(0.3))
	for i in range(h):
		img.set_pixel(0, i, border_color)
		img.set_pixel(w-1, i, border_color.darkened(0.3))

	return img

## 创建槽位贴图
func _create_slot_image(w: int, h: int, bg_color: Color, border_color: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg_color)

	# 绘制边框
	for i in range(w):
		img.set_pixel(i, 0, border_color)
		img.set_pixel(i, h-1, border_color)
	for i in range(h):
		img.set_pixel(0, i, border_color)
		img.set_pixel(w-1, i, border_color)

	# 角落加深
	if w > 0 and h > 0:
		img.set_pixel(0, 0, border_color.darkened(0.3))
		img.set_pixel(w-1, 0, border_color.darkened(0.3))
		img.set_pixel(0, h-1, border_color.darkened(0.3))
		img.set_pixel(w-1, h-1, border_color.darkened(0.3))

	return img

## 创建快捷栏/顶栏背景
func _create_bar_bg_image(w: int, h: int, bg_color: Color, border_color: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg_color)

	# 底部边框加粗
	for i in range(w):
		img.set_pixel(i, h-1, border_color)
		if h-2 >= 0:
			img.set_pixel(i, h-2, border_color.lightened(0.1))

	# 顶部高光
	for i in range(w):
		img.set_pixel(i, 0, bg_color.lightened(0.1))

	return img

## 添加标签文字（用像素块模拟）
func _add_label(img: Image, w: int, h: int, text: String) -> void:
	var label_h = min(14, h / 3)
	var label_w = min(text.length() * 7 + 4, w - 8)
	var start_x = (w - label_w) / 2
	var start_y = (h - label_h) / 2

	for y in range(start_y, start_y + label_h):
		for x in range(start_x, start_x + label_w):
			if y >= 0 and y < img.get_height() and x >= 0 and x < img.get_width():
				var pixel_color = img.get_pixel(x, y)
				# 如果像素是透明的，设置为标签颜色
				if pixel_color.a < 0.1:
					img.set_pixel(x, y, Color(1, 1, 1, 0.9))
				else:
					# 否则添加高亮
					img.set_pixel(x, y, pixel_color.lightened(0.3))

## 保存图像到文件
func _save_img(img: Image, path: String) -> int:
	var err = img.save_png(path)
	if err != OK:
		push_error("保存图片失败: " + path + " (错误: " + str(err) + ")")
		return 0
	print("  ✓ " + path.get_file())
	return 1
