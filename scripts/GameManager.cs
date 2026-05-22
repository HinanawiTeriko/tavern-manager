using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class GameManager : Node
{
    // ── 库存 ──
    private Dictionary<string, int> _inv = new()
    { ["Ale"]=999,["Wine"]=999,["Bread"]=999,["Meat"]=999,["Herb"]=999 };
    private static readonly string[] MatKeys = {"Ale","Wine","Bread","Meat","Herb"};
    private static readonly Dictionary<string,string> MN = new()
    { ["Ale"]="麦芽",["Wine"]="葡萄",["Bread"]="面粉",["Meat"]="生肉",["Herb"]="草药" };

    private Dictionary<string,(string N,string[] M,int P,bool C)> _rec;
    private string[] _oKeys;
    private string[] _barMat = new string[10];
    private int[] _barCnt = new int[10];
    private string _c1="",_c2="",_crafted="";
    private string _curN,_curO; private bool _custA; private double _custT;
    private const double PAT = 60.0;
    private int _g,_r; private double _spT,_nxS=2.0; private readonly Random _rng=new();
    private static readonly string[] Nms={"铁锤格鲁姆","冰霜莱拉","暗影德恩","圣光凯尔","疾风维克斯","暗夜尼克斯","山丘伯林","银弦艾莉亚","怒血索恩","黎明扎拉","磐石芬恩","毒刃鲁克"};

    private enum Df{None,Bar,Craft,BP}
    private Df _src=Df.None; private int _si=-1,_dragCnt=0; private string _dm=""; private bool _drag,_ok,_mo;
    private Panel _dp;
    private Label _gl,_repl,_cnl,_ol,_msg,_resL;
    private ProgressBar _tb;
    private ColorRect _cs;
    private Label _cb;
    private Button _cft,_srv,_clr;
    private Panel _mp;
    private ScrollContainer _recPanel,_bpPanel;
    private VBoxContainer _recL,_bpl;
    private Panel[] _bp=new Panel[5]; private Label[] _bplb=new Label[5];
    private ColorRect[] _br=new ColorRect[10]; private Label[] _blb=new Label[10];
    private ColorRect _cr1,_cr2; private Label _cl1,_cl2;

    public override void _Ready()
    {
        _rec=new(){
            ["Ale"]=("麦芽酒",new[]{"Ale"},5,false),["Wine"]=("葡萄酒",new[]{"Wine"},5,false),
            ["Bread"]=("面包",new[]{"Bread"},3,false),["Meat"]=("烤肉",new[]{"Meat"},4,false),
            ["Herb Tea"]=("草药茶",new[]{"Herb"},3,false),["Herbal Ale"]=("草药麦酒",new[]{"Ale","Herb"},10,true),
            ["Meat Stew"]=("肉汤",new[]{"Meat","Ale"},12,true),["MeatSand"]=("肉夹面包",new[]{"Bread","Meat"},9,true),
            ["SpicedWine"]=("香料红酒",new[]{"Wine","Herb"},11,true),
        }; _oKeys=_rec.Keys.ToArray();
        _dp=new Panel{Visible=false,MouseFilter=Control.MouseFilterEnum.Ignore,ZIndex=100};
    }

    public void StartGame(Node m){if(!_ok)Init(m);}
    private void TryAutoInit(){if(_ok)return;var r=GetTree().CurrentScene;if(r==null||r.Name!="Main")return;Init(r);}

    private void Init(Node m)
    {
        _gl=m.GL("UI/TopPanel/GoldLabel");_repl=m.GL("UI/TopPanel/ReputationLabel");
        _cnl=m.GL("UI/CustomerInfo/CustomerName");_ol=m.GL("UI/CustomerInfo/OrderText");
        _tb=m.GetNode<ProgressBar>("UI/CustomerInfo/TimerBar");_msg=m.GL("UI/MessageLabel");
        _cs=m.GetNode<ColorRect>("CustomerArea/CustomerSprite");_cb=m.GL("CustomerArea/OrderBubble");
        var bar=m.GetNode("UI/ShortcutBar");
        for(int i=0;i<10;i++){_br[i]=bar.GetNode<ColorRect>($"Slot{i}");_blb[i]=bar.GL($"Slot{i}/Label");}
        var cp=m.GetNode("UI/CraftPanel");
        _cr1=cp.GetNode<ColorRect>("CraftSlot1");_cr2=cp.GetNode<ColorRect>("CraftSlot2");
        _cl1=cp.GL("CraftSlot1/Label");_cl2=cp.GL("CraftSlot2/Label");
        _resL=cp.GL("ResultLabel");_cft=cp.GetNode<Button>("CraftButton");
        _clr=cp.GetNode<Button>("ClearButton");_srv=cp.GetNode<Button>("ServeButton");
        _cft.Pressed+=OnCraft;_clr.Pressed+=OnClear;_srv.Pressed+=OnServe;
        _mp=m.GetNode<Panel>("UI/OverlayMenu");
        _recL=_mp.GetNode<VBoxContainer>("RecipePanel/RecipeList");
        _bpl=_mp.GetNode<VBoxContainer>("BackpackPanel/BackpackList");
        _recPanel=_mp.GetNode<ScrollContainer>("RecipePanel");
        _bpPanel=_mp.GetNode<ScrollContainer>("BackpackPanel");
        _mp.GetNode<Button>("CloseBtn").Pressed+=ToggleMenu;
        _mp.GetNode<Button>("TabBtns/BtnRecipes").Pressed+=()=>{_recPanel.Visible=true;_bpPanel.Visible=false;};
        _mp.GetNode<Button>("TabBtns/BtnBackpack").Pressed+=()=>{_recPanel.Visible=false;_bpPanel.Visible=true;};
        // ── 背包 Grid ──
        var g=new GridContainer{Columns=3};
        for(int i=0;i<5;i++){
            var mk=MatKeys[i];
            var p=new Panel{CustomMinimumSize=new Vector2(200,56)};
            p.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.TopWide);
            var sb=new StyleBoxFlat{BgColor=MC(mk),BorderWidthLeft=3,BorderWidthTop=3,BorderWidthRight=3,BorderWidthBottom=3};
            p.AddThemeStyleboxOverride("panel",sb);
            var l=new Label{Text=$"{MN[mk]}  ×{_inv[mk]}",HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
            l.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            l.AddThemeColorOverride("font_color",Colors.White);
            l.AddThemeFontSizeOverride("font_size",16);
            p.AddChild(l);g.AddChild(p);_bp[i]=p;_bplb[i]=l;
        }
        _bpl.AddChild(g);
        m.GetNode<CanvasLayer>("UI").AddChild(_dp);
        // ── 配方表 ──
        foreach(var kv in _rec){
            var r=kv.Value;
            var row=new HBoxContainer{CustomMinimumSize=new Vector2(0,32)};
            row.AddThemeConstantOverride("separation",6);
            row.AddChild(MatBlock(r.M[0]));
            if(r.C){row.AddChild(MkL("  +  "));row.AddChild(MatBlock(r.M[1]));}
            row.AddChild(MkL("  =  "));
            row.AddChild(MkL($"{r.N}  {r.P}金币",160));
            _recL.AddChild(row);
        }
        // 初始快捷栏
        for(int i=0;i<5;i++){_barMat[i]=MatKeys[i];_barCnt[i]=5;}
        UpdAll();UpdUI();_srv.Disabled=true;_cb.Visible=false;_cs.Visible=false;
        _mp.Visible=false;Msg("欢迎！拖材料到右侧合成区，E键菜单",Colors.White);
        _ok=true;
    }

    // ── 配方表组件 ──
    static HBoxContainer MatBlock(string mk){
        var b=new HBoxContainer();b.AddThemeConstantOverride("separation",2);
        b.AddChild(new ColorRect{Color=MC(mk),CustomMinimumSize=new Vector2(36,24)});
        b.AddChild(MkL(MN.GetValueOrDefault(mk,mk),36));
        return b;
    }
    static Label MkL(string t,int w=0)=>new Label{Text=t,VerticalAlignment=VerticalAlignment.Center,
        CustomMinimumSize=new Vector2(w,0)}.WithWhiteText();

    // ── 主循环 ──
    public override void _Process(double dt){
        if(!_ok){TryAutoInit();return;}
        if(Input.IsActionJustPressed("menu_toggle"))ToggleMenu();
        if(!_mo&&_custA){_custT-=dt;_tb.Value=(_custT/PAT)*100.0;if(_custT<=0)OT();}
        if(!_custA&&!_mo){_spT+=dt;if(_spT>=_nxS){_spT=0;_nxS=_rng.NextDouble()*3+2;Spawn();}}
    }

    // ── 拖拽输入（新规则）──
    public override void _Input(InputEvent e){
        if(!_ok)return;
        if(e is InputEventMouseButton mb){
            if(mb.ButtonIndex==MouseButton.Left){
                if(mb.Pressed){if(_drag)DropAll();else PickUp(mb.Position);}
            }else if(mb.ButtonIndex==MouseButton.Right&&mb.Pressed){
                if(_drag)ReturnOne();else OnRClick(mb.Position);
            }
        }
        if(_drag&&e is InputEventMouseMotion mm)UpdateDP(mm.Position);
    }

    void PickUp(Vector2 p){
        if(HT(_cr1,p)&&!string.IsNullOrEmpty(_c1)){Start(Df.Craft,0,_c1);_c1="";UpdC();return;}
        if(HT(_cr2,p)&&!string.IsNullOrEmpty(_c2)){Start(Df.Craft,1,_c2);_c2="";UpdC();return;}
        for(int i=0;i<10;i++){
            if(HT(_br[i],p)&&!string.IsNullOrEmpty(_barMat[i])&&_barCnt[i]>0){
                _dragCnt=_barCnt[i];Start(Df.Bar,i,_barMat[i]);_barMat[i]="";_barCnt[i]=0;UpdB(i);return;
            }
        }
        if(_mo&&_bpPanel.Visible){
            for(int i=0;i<5;i++){
                if(HT(_bp[i],p)&&_inv[MatKeys[i]]>0){
                    _dragCnt=_inv[MatKeys[i]];Start(Df.BP,i,MatKeys[i]);_inv[MatKeys[i]]=0;UpdBL(i);return;
                }
            }
        }
    }

    void DropAll(){
        if(!_drag)return;
        var p=GetViewport().GetMousePosition();
        if(HT(_cr1,p)&&string.IsNullOrEmpty(_c1)){_c1=_dm;UpdC();Finish();return;}
        if(HT(_cr2,p)&&string.IsNullOrEmpty(_c2)){_c2=_dm;UpdC();Finish();return;}
        for(int i=0;i<10;i++){if(HT(_br[i],p)&&string.IsNullOrEmpty(_barMat[i])){_barMat[i]=_dm;_barCnt[i]=_dragCnt;UpdB(i);Finish();return;}}
        for(int i=0;i<10;i++){if(HT(_br[i],p)&&_barMat[i]==_dm){_barCnt[i]+=_dragCnt;UpdB(i);Finish();return;}}
        if(_mo&&_bpPanel.Visible){for(int i=0;i<5;i++){if(HT(_bp[i],p)){_inv[MatKeys[i]]+=_dragCnt;UpdBL(i);Finish();return;}}}
        ReturnAll();Finish();
    }

    void ReturnOne(){
        _dragCnt--;
        switch(_src){
            case Df.Bar:_barMat[_si]=_dm;_barCnt[_si]=1;UpdB(_si);break;
            case Df.Craft:if(_si==0)_c1=_dm;else _c2=_dm;UpdC();break;
            case Df.BP:_inv[_dm]=1;UpdBL(_si);break;
        }
        if(_dragCnt<=0){Finish();return;}
        UpdDPCount();
    }

    void ReturnAll(){
        switch(_src){
            case Df.Bar:_barMat[_si]=_dm;_barCnt[_si]+=_dragCnt;UpdB(_si);break;
            case Df.Craft:if(_si==0)_c1=_dm;else _c2=_dm;UpdC();break;
            case Df.BP:_inv[_dm]+=_dragCnt;UpdBL(_si);break;
        }
    }

    void Start(Df s,int i,string m){_src=s;_si=i;_dm=m;_drag=true;ShowDP();}
    void Finish(){_drag=false;HideDP();_src=Df.None;_si=-1;_dm="";_dragCnt=0;UpdAll();UpdAllBL();_srv.Disabled=string.IsNullOrEmpty(_c1)||!_custA;}

    void ShowDP(){_dp.Visible=true;_dp.Size=new Vector2(48,48);_dp.Position=GetViewport().GetMousePosition()-new Vector2(24,24);
        var sb=new StyleBoxFlat{BgColor=MC(_dm),BorderWidthLeft=2,BorderWidthTop=2,BorderWidthRight=2,BorderWidthBottom=2};
        _dp.AddThemeStyleboxOverride("panel",sb);
    }
    void HideDP(){_dp.Visible=false;}
    void UpdateDP(Vector2 pos){_dp.Position=pos-new Vector2(24,24);}
    void UpdDPCount(){/* TODO: 贴图数字 */}

    // 右键非拖拽时 → 退回合成区材料
    void OnRClick(Vector2 p){
        if(HT(_cr1,p)&&!string.IsNullOrEmpty(_c1)){Ret1(_c1);_c1="";UpdC();}
        else if(HT(_cr2,p)&&!string.IsNullOrEmpty(_c2)){Ret1(_c2);_c2="";UpdC();}
    }
    void Ret1(string m){for(int i=0;i<10;i++){if(_barMat[i]==m){_barCnt[i]++;UpdB(i);return;}}for(int i=0;i<10;i++){if(string.IsNullOrEmpty(_barMat[i])){_barMat[i]=m;_barCnt[i]=1;UpdB(i);return;}}_inv[m]++;}

    static bool HT(Control c,Vector2 p){var r=c.GetGlobalRect();return p.X>=r.Position.X&&p.X<=r.End.X&&p.Y>=r.Position.Y&&p.Y<=r.End.Y;}

    // ── 合成 ──
    void OnCraft(){
        if(string.IsNullOrEmpty(_c1)){Msg("请先拖入材料！",Colors.Orange);return;}
        var ing=new List<string>{_c1};if(!string.IsNullOrEmpty(_c2))ing.Add(_c2);ing.Sort();
        string mt=null;foreach(var kv in _rec){var rq=new List<string>(kv.Value.M);rq.Sort();if(ing.SequenceEqual(rq)){mt=kv.Key;break;}}
        if(mt!=null){_crafted=mt;_resL.Text=$"[{_rec[mt].N}]";_resL.AddThemeColorOverride("font_color",Colors.GreenYellow);_srv.Disabled=false;_c1=_c2="";UpdC();Msg($"制作完成：{_rec[mt].N}！",Colors.GreenYellow);}
        else{_crafted="";_resL.Text="[无效配方]";_resL.AddThemeColorOverride("font_color",Colors.OrangeRed);Msg("没有匹配的配方！",Colors.OrangeRed);}
    }
    void OnClear(){if(!string.IsNullOrEmpty(_c2)){Ret1(_c2);_c2="";}if(!string.IsNullOrEmpty(_c1)){Ret1(_c1);_c1="";}_crafted="";_resL.Text="";UpdC();_srv.Disabled=true;UpdAll();Msg("已清空合成区。",Colors.Gray);}
    void UpdC(){_cr1.Color=string.IsNullOrEmpty(_c1)?new(0.15f,0.12f,0.1f):MC(_c1);_cr2.Color=string.IsNullOrEmpty(_c2)?new(0.15f,0.12f,0.1f):MC(_c2);_cl1.Text=string.IsNullOrEmpty(_c1)?" ":MN[_c1];_cl2.Text=string.IsNullOrEmpty(_c2)?" ":MN[_c2];}

    // ── 客人 ──
    void Spawn(){_curN=Nms[_rng.Next(Nms.Length)];_curO=_oKeys[_rng.Next(_oKeys.Length)];_custA=true;_custT=PAT;_cs.Visible=true;_cb.Visible=true;_cnl.Text=_curN;_ol.Text=$"需要：{_rec[_curO].N}";_cb.Text=$"「来一份{_rec[_curO].N}！」";float ox=_rng.Next(2)==0?-220:220;_cb.Position=new Vector2(540+ox,60);_srv.Disabled=true;_crafted="";_c1=_c2="";UpdC();_resL.Text="";_tb.Value=100;Msg($"{_curN} 走进了酒馆！",Colors.White);}
    void OT(){Msg($"{_curN} 等不及，离开了……",Colors.OrangeRed);Clr();}
    void Clr(){_custA=false;_cs.Visible=false;_cb.Visible=false;_cnl.Text="等待中……";_ol.Text="暂无客人";_srv.Disabled=true;_spT=0;_nxS=_rng.NextDouble()*2+2;_c1=_c2=_crafted="";UpdC();_resL.Text="";_tb.Value=0;}
    void OnServe(){if(!_custA||string.IsNullOrEmpty(_crafted))return;if(_crafted==_curO){_g+=_rec[_crafted].P;_r++;UpdUI();Msg($"完美！{_curN} 支付了 {_rec[_crafted].P} 金币！",Colors.LimeGreen);}else Msg($"错了！{_curN} 很生气！",Colors.Red);Clr();}

    // ── UI ──
    void UpdB(int i){_br[i].Color=string.IsNullOrEmpty(_barMat[i])?new(0.1f,0.08f,0.06f):MC(_barMat[i]);_blb[i].Text=string.IsNullOrEmpty(_barMat[i])?"":$"{MN[_barMat[i]]}\n{_barCnt[i]}";}
    void UpdAll(){for(int i=0;i<10;i++)UpdB(i);UpdC();}
    void UpdBL(int i){_bplb[i].Text=$"{MN[MatKeys[i]]}  ×{_inv[MatKeys[i]]}";}
    void UpdAllBL(){for(int i=0;i<5;i++)UpdBL(i);}
    void UpdUI(){_gl.Text=$"金币：{_g}";_repl.Text=$"声望：{_r}";}
    void ToggleMenu(){_mo=!_mo;_mp.Visible=_mo;if(_mo)UpdAllBL();}
    void Msg(string t,Color c){_msg.Text=t;_msg.AddThemeColorOverride("font_color",c);}

    static Color MC(string m)=>m switch{"Ale"=>new(0.8f,0.6f,0.2f),"Wine"=>new(0.6f,0.1f,0.2f),"Bread"=>new(0.7f,0.55f,0.3f),"Meat"=>new(0.65f,0.2f,0.1f),"Herb"=>new(0.2f,0.7f,0.2f),_=>Colors.Gray};
}

// ── 扩展 ──
static class Ex{public static Label GL(this Node n,string p)=>n.GetNode<Label>(p);
    public static Label WithWhiteText(this Label l){l.AddThemeColorOverride("font_color",Colors.White);l.AddThemeFontSizeOverride("font_size",15);return l;}
}
