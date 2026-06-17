# Shop Clean Component Table

Scale: native pixels export at 4x runtime scale.

Source rules:
- `shop_final_interface_right_page_controls_v2_dark.png` is structure reference only.
- Production pixels come from clean generated/native component sources.
- Default components and complete state components are generated on the same source sheet.
- Runtime UI references `res://assets/textures/daymap/shop_clean/`.
- All dynamic text is rendered by Godot labels.
- Hover/selected/pressed/disabled use full replacement textures, not marker overlays.
- Owned recipe/ability state is text-only in `DetailPanel/State`; the legacy `DetailPanel/OwnedMark` node remains as an empty hidden compatibility node and must not reference cropped status art.

| id | native_size | runtime_size | runtime_node_path | states | safe_area_native | godot_use | notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| shop_clean_backdrop | 320x180 | 1280x720 | ShopBackdrop | normal | none | TextureRect | generated v7 stage matching original dark teal backdrop, lower-left pouch clear of the left panel and hooded shopkeeper readable in the panel gap, no text |
| shop_clean_list_panel | 170x100 | 680x400 | MainBrushPanel/ListPanel | normal | 12,10,156,86 | TextureRect | stacked left item ledger base |
| shop_clean_detail_page_base | 108x130 | 432x520 | MainBrushPanel/DetailPageBase | normal | 8,8,92,114 | TextureRect | right detail/order page base only |
| shop_clean_detail_title_slip | 92x16 | 368x64 | DetailPage/TitleSlipArt | normal | 6,3,82,10 | TextureRect | clean title paper slip |
| shop_clean_detail_body_panel | 92x52 | 368x208 | DetailPage/BodyPanelArt | normal | 6,5,82,42 | TextureRect | clean description paper area |
| shop_clean_detail_uses_panel | 92x20 | 368x80 | DetailPage/UsesPanelArt | normal | 6,4,82,14 | TextureRect | clean uses paper strip |
| shop_clean_gold_tag | 36x14 | 144x56 | DetailPage/GoldTagArt | normal | 6,3,30,10 | TextureRect | coin/stat tag on right page |
| shop_clean_tab | 42x16 | 168x64 | CategoryTabs/*Art | normal, hover, selected | 7,3,30,9 | TextureRect | generated v2 source, lower-contrast title/menu band treatment |
| shop_clean_item_row | 145x16 | 580x64 | ItemList/Item_*/RowArt | normal, hover, selected, disabled | 19,3,120,9 | TextureRect | independent product row, name and price lanes inside |
| shop_clean_quantity_button_minus | 9x9 | 36x36 | CheckoutBar/QuantityControl/MinusArt | normal, hover, disabled | none | TextureRect | generated v5 source, pixelized to match compact runtime size |
| shop_clean_quantity_button_plus | 9x9 | 36x36 | CheckoutBar/QuantityControl/PlusArt | normal, hover, disabled | none | TextureRect | generated v5 source, pixelized to match compact runtime size |
| shop_clean_quantity_body | 9x9 | 36x36 | CheckoutBar/QuantityControl/BodyArt | normal | 2,2,7,7 | TextureRect | quantity value background |
| shop_clean_purchase_receipt | 64x18 | 256x72 | DetailPage/PurchaseReceiptArt | normal | 8,4,48,10 | TextureRect | small receipt strip on detail page |
| shop_clean_purchase_seal | 24x24 | 96x96 | DetailPage/PurchaseSealArt | normal, hover, pressed, disabled | none | TextureRect | wax seal button on detail page |
| shop_clean_close_tag | 20x32 | 80x128 | DetailPage/CloseTagArt | normal, hover | none | TextureRect | hanging paper tag with loop |

Text lanes:
- tab label: runtime `34,12,120,34`
- row name: runtime `76,11,300,34`
- row price: runtime `448,11,108,34`
- detail title: runtime `36,32,320,40`
- detail description: runtime `36,92,320,128`
- detail uses: runtime `36,236,320,84`
- gold label: runtime `36,376,104,30`
- quantity label: runtime `188,372,72,48`
- purchase label: runtime `292,376,92,36`
