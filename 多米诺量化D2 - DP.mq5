#property strict
#property version   "1.00"
#property description "多米诺量化D2-DeepSeek版"

#include <Trade/Trade.mqh>

enum OpenModeEnum
  {
   OpenMode_Bar      = 1,
   OpenMode_Interval = 2,
   OpenMode_NoDelay  = 3
  };

enum DeepSeekMarketState
  {
   DeepSeekState_Range   = 0,
   DeepSeekState_Warning = 1,
   DeepSeekState_Trend   = 2
  };

enum DeepSeekDirection
  {
   DeepSeekDirection_None = 0,
   DeepSeekDirection_Up   = 1,
   DeepSeekDirection_Down = -1
  };
string LicenseCode=""; // 授权码逻辑已关闭
bool     LicenseEnabled=false;

input string tishi = "投资有风险，入市需谨慎！"; // 风险提示
input group "网格参数"
double               On_top_of_this_price_not_Buy_order      = 0.0;     // B以上不开(补)
double               On_under_of_this_price_not_Sell_order   = 0.0;     // S以下不开(补)
string               Limit_StartTime                         = "00:00"; // 限价开始时间
string               Limit_StopTime                          = "24:00"; // 限价结束时间
bool                 CloseBuySell                            = true;    // 逆势保护开关
bool                 HomeopathyCloseAll                      = true;    // 顺势保护开关
bool                 Homeopathy                              = false;   // 完全对锁时挂上顺势开关
bool                 Over                                    = false;   // 平仓后停止交易
int                  NextTime                                = 0;       // 整体平仓后多少秒后新局
input double         Money                                   = 2000.0;     // 浮亏多少启用第二参数
input int            FirstStep                               = 30;      // 首单距离
input int            MinDistance                             = 80;      // 最小距离
input int            TwoMinDistance                          = 120;      // 第二最小距离
input int            StepTrallOrders                         = 5;       // 挂单追踪点数
input int            Step                                    = 100;     // 补单间距
input int            TwoStep                                 = 180;     // 第二补单间距
OpenModeEnum         OpenMode                                = OpenMode_NoDelay; // 开单模式
input ENUM_TIMEFRAMES      TimeZone                               = PERIOD_M1; // 开单时区
int            sleep                                   = 30;      // 开单时间间距(秒)
double         MaxLoss                                 = 100000.0;// 单边浮亏超过多少不继续加仓
double         MaxLossCloseAll                         = 50.0;    // 单边平仓限制

input group "风控参数"
input double         lot                                     = 0.01;    // 起始手数
 double         Maxlot                                  = 10.0;    // 最大开单手数
 double         PlusLot                                 = 0.0;     // 累加手数
input double         K_Lot                                   = 1.3;     // 倍率
 int            DigitsLot                               = 2;       // 下单量小数位
 double         CloseAll                                = 0.5;     // 整体平仓金额
 bool           Profit                                  = true;    // 单边平仓金额累加开关
 double         StopProfit                              = 2.0;     // 单边平仓金额
input double         StopLoss                                = 0.0;     // 止损金额
input bool           EnableDailyLossStop                     = true;    // 启用每日亏损保护
input double         DailyLossStopPct                        = 60.0;    // 每日最大亏损比例(%)
long                 Magic                                   = 958999848; // 魔术号
 int            Totals                                  = 50;      // 最大单量
int                  MaxSpread                               = 60;      // 点差限制(点)
int                  Leverage                                = 100;     // 平台杠杆限制

// 交易时段参数隐藏，不在参数页显示
bool                 EnableTradingSessionWindow             = false;    // 启用工作时间段控制
string               EA_StartTime                            = "00:00"; // EA开始时间
string               EA_StopTime                             = "24:00"; // EA结束时间
input bool                 EnableDailyAutoStart                    = true;     // 启用每日自动启动
input string               DailyAutoStartTime                      = "07:30"; // 每日自动启动时间
bool                 EnableDailyWrapUpPhase                 = false;    // 启用日内收尾阶段
string               DailyWrapUpStartTime                   = "20:00"; // 收尾开始(盘面/服务器时间)
string               DailyWrapUpStopTime                    = "24:00"; // 收尾结束(盘面/服务器时间)
bool                 EnableDailyProfitTarget                = false;    // 启用每日盈利目标
double               DailyProfitTarget                       = 50.0;    // 每日盈利目标，达到后封盘

input group "DeepSeek单边保护"
input string DeepSeekApiKey = "在这里填写API_KEY"; // DeepSeek API Key
input string DeepSeekModel = "deepseek-v4-flash"; // DeepSeek模型
input string DeepSeekUrl = "https://api.deepseek.com/chat/completions"; // DeepSeek接口地址
input int DeepSeekTimeoutMs = 10000; // DeepSeek超时毫秒
input int DeepSeekResultValidMinutes = 15; // AI结果有效分钟
input int DeepSeekAtrPeriod = 14; // WARNING补仓ATR周期
input int DeepSeekAtrAverageBars = 20; // WARNING补仓ATR均值根数
input double DeepSeekWarningMinDistanceMultiplier = 1.30; // WARNING补仓最低倍数
input double DeepSeekWarningMaxDistanceMultiplier = 3.00; // WARNING补仓最高倍数
input double DeepSeekTrendMaxLossPct = 15.0; // TREND最大亏损止损比例(%)
input double DeepSeekTrendRetraceAtrMultiplier = 0.50; // TREND回撤减仓ATR倍数
input double DeepSeekTrendContinueAtrMultiplier = 0.30; // TREND继续推进减仓ATR倍数
input bool DeepSeekPrintPayload = false; // 测试日志打印完整payload

// 本地授权配置：每个账号对应一个到期时间；服务器留空表示不限制服务器。
input group "显示设置"
input color          clr1                                    = MediumSeaGreen; // 多单均价线
input color          clr2                                    = Crimson;        // 空单均价线

struct EAStats
  {
   int               buy_positions;
   int               sell_positions;
   int               buy_pending;
   int               sell_pending;
   double            buy_lots;
   double            sell_lots;
   double            buy_profit;
   double            sell_profit;
   double            total_profit;
   double            buy_weighted_sum;
   double            sell_weighted_sum;
   double            buy_avg_price;
   double            sell_avg_price;
   double            buy_highest_any;
   double            buy_lowest_position;
   double            sell_highest_position;
   double            sell_lowest_any;
   double            buy_pending_price;
   double            sell_pending_price;
   ulong             buy_pending_ticket;
   ulong             sell_pending_ticket;
   datetime          last_buy_open_time;
   datetime          last_sell_open_time;
  };

struct PanelMetrics
  {
   int               margin_x;
   int               margin_y;
   int               width;
   int               pad;
   int               section_gap;
   int               header_h;
   int               row_h;
   int               gap;
   int               button_h;
   int               inner_w;
   int               half_w;
   int               card_status_h;
   int               card_metrics_h;
   int               card_actions_h;
   int               button_font;
   int               font_sm;
   int               font_xs;
   int               font_md;
   int               font_lg;
   bool              compact;
   int               panel_h;
   int               toggle_w;
  };

struct DeepSeekResult
  {
   bool              ok;
   DeepSeekMarketState state;
   int               confidence;
   DeepSeekDirection direction;
   string            reason_code;
   string            raw_json;
  };


CTrade               g_trade;
bool                 g_allow_buy              = true;
bool                 g_allow_sell             = true;
bool                 g_panel_open             = true;
datetime             g_pause_until            = 0;
datetime             g_last_open_bar_time     = 0;
datetime             g_last_panel_refresh     = 0;
double               g_max_loss_limit         = 0.0;
double               g_max_loss_close_all     = 0.0;
double               g_stop_loss_limit        = 0.0;
double               g_second_loss_threshold  = 0.0;
double               g_deposit_base           = 100.0;
double               g_buy_protection_peak    = 0.0;
double               g_sell_protection_peak   = 0.0;
string               g_today_key              = "";
bool                 g_daily_target_locked    = false;
double               g_daily_target_hit_value = 0.0;
string               g_daily_loss_key         = "";
double               g_daily_loss_base_equity = 0.0;
bool                 g_daily_loss_triggered   = false;
bool                 g_daily_loss_alerted     = false;
string               g_daily_auto_start_key   = "";
string               g_panel_prefix           = "GoldKylinMT5.";
DeepSeekMarketState  g_deepseek_state         = DeepSeekState_Range;
DeepSeekDirection    g_deepseek_direction     = DeepSeekDirection_None;
datetime             g_deepseek_last_m5_bar   = 0;
datetime             g_deepseek_last_success  = 0;
bool                 g_deepseek_result_ok     = false;
int                  g_deepseek_confidence    = 0;
string               g_deepseek_reason_code   = "INSUFFICIENT_DATA";
string               g_deepseek_status_reason = "等待DeepSeek首次确认";
string               g_deepseek_raw_response  = "";
string               g_deepseek_last_ai_state = "NONE";
int                  g_deepseek_http_status   = 0;
int                  g_deepseek_warning_hits  = 0;
int                  g_deepseek_trend_hits    = 0;
int                  g_deepseek_nontrend_hits = 0;
int                  g_deepseek_range_hits    = 0;
double               g_deepseek_m15_atr_ratio = 1.0;
datetime             g_deepseek_trend_last_manage_m5 = 0;
DeepSeekDirection    g_deepseek_trend_manage_direction = DeepSeekDirection_None;
double               g_deepseek_trend_extreme_price = 0.0;
string               g_deepseek_trend_manage_reason = "等待TREND";

#define GOLDKING_ORDER_COMMENT_PRIMARY   "FXKiller_GoldKing"
#define GOLDKING_ORDER_COMMENT_SECONDARY "FXKiller_GoldKing_SS"

bool       IsTestingMode();
datetime   ReferenceNow();
bool       CheckLocalLicense(const bool show_alert);
string     LicenseHash(const string text);
string     Hex64(const ulong value);
string     LicensePayload(const string account,const string expire_date,const string server);
bool       CheckLicenseCode(const bool show_alert,const long login,const string server,const datetime now_value);
string     CleanTimeString(const string value);
datetime   TodayAt(const string time_text,const datetime now_value);
bool       IsInWindow(const string start_text,const string stop_text,const datetime now_value);
bool       IsAfterSessionStop(const datetime now_value);
bool       IsTradingSessionOpen(const datetime now_value);
bool       IsTradingSessionAfterStop(const datetime now_value);
bool       IsDailyWrapUpWindow(const datetime now_value);
void       CheckDailyAutoStart();
double     PipDivisor();
double     CurrentSpreadPoints();
int        VolumeDigits(const double step);
double     NormalizeVolumeToSymbol(double volume);
double     NormalizePriceToSymbol(double price);
int        BrokerMinDistancePoints();
bool       IsHedgingAccount();
void       ResetStats(EAStats &stats);
void       CollectStats(EAStats &stats);
double     CalculateDepositBase();
double     CalculateClosedProfit(const datetime from_time,const datetime to_time,const long magic_filter,const bool current_symbol_only);
string     TradingDayKey(const datetime now_value);
double     TodayClosedProfit(const datetime now_value);
double     TodayProgressProfit(const datetime now_value,const EAStats &stats);
bool       HasOpenPositions(const EAStats &stats);
bool       HasActiveExposure(const EAStats &stats);
void       RefreshDailyLocks(const datetime now_value,const EAStats &stats);
void       RefreshDailyLossBase(const datetime now_value);
bool       CheckDailyLossStop(const bool show_alert);
double     AccountProfitForPanel();
int        CountPositionsWithComment(const string comment_text,const ENUM_POSITION_TYPE type);
double     SumExtremePositionProfits(const ENUM_POSITION_TYPE type,const bool positive,const int count);
ulong      FindExtremePositionTicket(const ENUM_POSITION_TYPE type,const bool positive);
double     FindExtremePositionLot(const ENUM_POSITION_TYPE type,const bool positive);
void       CloseExtremePositions(const ENUM_POSITION_TYPE type,int count,const bool positive);
ulong      FindNewestPositionTicket(const ENUM_POSITION_TYPE type,const bool current_symbol_only,const long magic_filter);
bool       CloseByPair(const ulong position_ticket,const ulong opposite_ticket);
void       CloseOppositePairs();
bool       TradeRetcodeOk(const uint retcode);
bool       CheckTradeResult(const bool request_ok,const string action);
bool       CheckOrderSendResult(const bool request_ok,const MqlTradeResult &result,const string action);
bool       ClosePositionTicket(const ulong ticket);
bool       DeletePendingOrder(const ulong ticket);
void       DeleteEaPendingOrders();
bool       ModifyPendingPrice(const ulong ticket,const double new_price);
void       CloseEaOrders(const int direction,const bool use_pairs,const bool arm_cooldown);
void       ClosePositionsByProfitState(const bool close_profit);
void       CloseCurrentSymbolPositions();
void       CloseAllAccountPositions();
string     DeepSeekStateText(const DeepSeekMarketState state);
string     DeepSeekDirectionText(const DeepSeekDirection direction);
bool       DeepSeekIsConfigured();
bool       DeepSeekResultFresh();
bool       DeepSeekBlocksNewCycle();
bool       DeepSeekBlocksGrid();
bool       IsEaStrategyOrderComment(const string comment_text);
void       DeleteEaStrategyPendingOrders();
string     JsonEscape(const string text);
string     DeepSeekCandleJson(const ENUM_TIMEFRAMES timeframe,const int bars);
double     DeepSeekFloatingLossPct(const EAStats &stats);
string     BuildDeepSeekPayload(const EAStats &stats);
bool       ExtractJsonStringField(const string json,const string field,string &value);
bool       ExtractJsonNumberField(const string json,const string field,double &value);
string     JsonUnescape(const string text);
DeepSeekMarketState DeepSeekStateFromText(const string text);
DeepSeekDirection DeepSeekDirectionFromText(const string text);
bool       ParseDeepSeekResponse(const string response,DeepSeekResult &parsed);
bool       CallDeepSeekApi(const EAStats &stats,DeepSeekResult &parsed);
void       ApplyDeepSeekDebounce(const DeepSeekResult &parsed);
void       UpdateDeepSeekOnNewM5(const EAStats &stats);
double     CalculateM15AtrRatio();
double     CalculateCurrentM15Atr();
int        DeepSeekAdjustedGridDistance(const int base_points);
bool       ApplyDeepSeekTrendRiskManagement(EAStats &stats);
bool       IsTradingEnvironmentOk(const EAStats &stats,string &reason);
void       UpdateLimitLines();
void       UpdateAverageLines(const EAStats &stats);
bool       ShouldUsePrimaryParameters(const EAStats &stats);
bool       AllowBuyOrderByPriceLimit(const EAStats &stats,const double target_price,const bool limit_window_active);
bool       AllowSellOrderByPriceLimit(const EAStats &stats,const double target_price,const bool limit_window_active);
bool       CanOpenThisCycle(const bool is_buy,const EAStats &stats);
bool       TryProtectiveCloseBySide(const EAStats &stats);
bool       ApplyCloseBuySellProtection(const EAStats &stats);
bool       TryAutoCloseLogic(const EAStats &stats);
void       TryPlacePendingOrders(const EAStats &stats,const bool allow_buy,const bool allow_sell);
void       TryTrailPendingOrders(const EAStats &stats,const bool allow_buy,const bool allow_sell);
void       ExecuteStrategy();
double     UiScale();
double     UiFontScale();
int        ScalePx(const int value);
int        ScaleFont(const int value);
void       BuildPanelMetrics(PanelMetrics &m);
void       EnsureRectangle(const string name,const int x,const int y,const int w,const int h,const color bg,const color border,const int corner);
void       EnsureLabel(const string name,const string text,const int x,const int y,const int font_size,const color clr,const int corner,const string font="Microsoft YaHei");
void       EnsureButton(const string name,const string text,const int x,const int y,const int w,const int h,const color bg,const color fg,const int corner);
string     BoolText(const bool enabled,const string on_text,const string off_text);
string     FormatSignedMoney(const double value);
string     FormatPercent(const double value);
string     FormatPanelMoment(const datetime when,const datetime now_value);
string     WrapUpPauseReason(const EAStats &stats);
string     SessionStateText(const datetime now_value,const EAStats &stats);
string     WrapUpStateText(const EAStats &stats);
string     GoalStateText(const double target_progress_display);
string     EntryStateText(const string stop_reason);
string     CloseReasonText();
string     ClipText(const string text,const int max_chars);
string     TimeframeLabel(const ENUM_TIMEFRAMES timeframe);
void       DrawPanel(const EAStats &stats);
void       RefreshPanel(const bool force);
void       DeleteObjectsByPrefix(const string prefix);

int OnInit()
  {
   if(!CheckLocalLicense(true))
      return(INIT_FAILED);

   g_trade.SetExpertMagicNumber(Magic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints((_Digits == 3 || _Digits == 5) ? 30 : 3);

   g_allow_buy             = true;
   g_allow_sell            = true;
   g_panel_open            = true;
   g_pause_until           = 0;
   g_last_open_bar_time    = 0;
   g_last_panel_refresh    = 0;
   g_buy_protection_peak   = 0.0;
   g_sell_protection_peak  = 0.0;
   g_max_loss_limit        = -MathAbs(MaxLoss);
   g_max_loss_close_all    = -MathAbs(MaxLossCloseAll);
   g_stop_loss_limit       = -MathAbs(StopLoss);
   g_second_loss_threshold = -MathAbs(Money);
   g_deposit_base          = CalculateDepositBase();
   RefreshDailyLossBase(ReferenceNow());

   DeleteObjectsByPrefix(g_panel_prefix);
   EventSetTimer(1);
   RefreshPanel(true);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteObjectsByPrefix(g_panel_prefix);
  }

void OnTick()
  {
   if(!CheckLocalLicense(false))
      return;

   if(CheckDailyLossStop(true))
     {
      RefreshPanel(true);
      return;
     }

   ExecuteStrategy();
  }

void OnTimer()
  {
   if(!CheckLocalLicense(false))
      return;

   CheckDailyLossStop(true);
   CheckDailyAutoStart();
   RefreshPanel(false);
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(!CheckLocalLicense(true))
      return;

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   const string key=sparam;
   if(StringFind(key,g_panel_prefix + "display_green",0) == 0)
     {
      const bool currently_on=(g_allow_buy || g_allow_sell);
      g_allow_buy = !currently_on;
      g_allow_sell = !currently_on;
      RefreshPanel(true);
      return;
     }

   if(StringFind(key,g_panel_prefix + "display_red",0) == 0)
     {
      DeleteEaPendingOrders();
      CloseAllAccountPositions();
      RefreshPanel(true);
      return;
     }
  }
bool IsTestingMode()
  {
   return((bool)MQLInfoInteger(MQL_TESTER));
  }

datetime ReferenceNow()
  {
   return(IsTestingMode() ? TimeCurrent() : TimeLocal());
  }


bool CheckLocalLicense(const bool show_alert)
  {
   return(true);
  }
string Hex64(const ulong value)
  {
   string result="";
   for(int i=15; i>=0; --i)
     {
      const int nibble=(int)((value >> (i * 4)) & 0x0F);
      result+=StringSubstr("0123456789ABCDEF",nibble,1);
     }
   return(result);
  }

string LicenseHash(const string text)
  {
   ulong hash=0xcbf29ce484222325;
   for(int i=0; i<StringLen(text); ++i)
     {
      const ushort ch=StringGetCharacter(text,i);
      hash^=(uchar)(ch & 0xFF);
      hash*=0x100000001b3;
     }
   return(Hex64(hash));
  }

string LicensePayload(const string account,const string expire_date,const string server)
  {
   const string secret="DominoD2-License-2026-P7s9Q2";
   return("DOMINO-D2|" + account + "|" + expire_date + "|" + server + "|" + secret);
  }

bool CheckLicenseCode(const bool show_alert,const long login,const string server,const datetime now_value)
  {
   string code=LicenseCode;
   StringTrimLeft(code);
   StringTrimRight(code);
   StringReplace(code," ","");
   StringReplace(code,"-","");
   StringToUpper(code);
   if(code == "")
      return(false);

   static string cached_code="";
   static bool cached_result=false;
   static datetime cached_until=0;
   if(code == cached_code)
     {
      if(cached_result && now_value <= cached_until)
         return(true);
      if(!cached_result)
         return(false);
     }

   cached_code=code;
   cached_result=false;
   cached_until=0;

   if(StringLen(code) != 16)
     {
      if(show_alert)
         Alert("授权失败：授权码格式错误，应为16位授权码");
      Print("授权失败：授权码格式错误，code=",code);
      return(false);
     }

   for(int i=0; i<StringLen(code); ++i)
     {
      const ushort ch=StringGetCharacter(code,i);
      const bool is_hex=(ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'F');
      if(!is_hex)
        {
         if(show_alert)
            Alert("授权失败：授权码格式错误，应为16位授权码");
         Print("授权失败：授权码包含非法字符，code=",code);
         return(false);
        }
     }

   MqlDateTime now_struct={};
   TimeToStruct(now_value,now_struct);
   datetime scan_date=StringToTime(StringFormat("%04d.%02d.%02d 23:59:59",now_struct.year,now_struct.mon,now_struct.day));
   const datetime max_date=StringToTime("2099.12.31 23:59:59");
   const string account_text=IntegerToString(login);

   while(scan_date > 0 && scan_date <= max_date)
     {
      MqlDateTime scan_struct={};
      TimeToStruct(scan_date,scan_struct);
      const string expire_text=StringFormat("%04d.%02d.%02d",scan_struct.year,scan_struct.mon,scan_struct.day);

      if(code == LicenseHash(LicensePayload(account_text,expire_text,"*")) ||
         code == LicenseHash(LicensePayload(account_text,expire_text,server)))
        {
         cached_result=true;
         cached_until=scan_date;
         return(true);
        }

      scan_date+=86400;
     }

   if(show_alert)
      Alert("授权失败：授权码无效、账号不匹配或授权已到期，当前账号=",login);
   Print("授权失败：授权码无效、账号不匹配或授权已到期，login=",login," server=",server);
   return(false);
  }
string CleanTimeString(const string value)
  {
   string result=value;
   StringReplace(result," ","");
   StringTrimLeft(result);
   StringTrimRight(result);
   if(result == "24:00")
      result="23:59:59";
   return(result);
  }

datetime TodayAt(const string time_text,const datetime now_value)
  {
   string t=CleanTimeString(time_text);
   if(StringLen(t) == 5)
      t+=":00";
   return(StringToTime(TimeToString(now_value,TIME_DATE) + " " + t));
  }

bool IsInWindow(const string start_text,const string stop_text,const datetime now_value)
  {
   const datetime start_time=TodayAt(start_text,now_value);
   const datetime stop_time=TodayAt(stop_text,now_value);
   if(start_time <= stop_time)
      return(now_value >= start_time && now_value <= stop_time);
   return(now_value >= start_time || now_value <= stop_time);
  }

bool IsAfterSessionStop(const datetime now_value)
  {
   if(IsInWindow(EA_StartTime,EA_StopTime,now_value))
      return(false);

   const datetime start_time=TodayAt(EA_StartTime,now_value);
   const datetime stop_time=TodayAt(EA_StopTime,now_value);
   if(start_time <= stop_time)
      return(now_value > stop_time);
   return(now_value > stop_time && now_value < start_time);
  }

bool IsTradingSessionOpen(const datetime now_value)
  {
   if(!EnableTradingSessionWindow)
      return(true);
   return(IsInWindow(EA_StartTime,EA_StopTime,now_value));
  }

bool IsTradingSessionAfterStop(const datetime now_value)
  {
   if(!EnableTradingSessionWindow)
      return(false);
   return(IsAfterSessionStop(now_value));
  }

bool IsDailyWrapUpWindow(const datetime now_value)
  {
   if(!EnableDailyWrapUpPhase)
      return(false);
   return(IsInWindow(DailyWrapUpStartTime,DailyWrapUpStopTime,now_value));
  }

void CheckDailyAutoStart()
  {
   if(!EnableDailyAutoStart)
      return;

   const datetime now_value=ReferenceNow();
   const datetime start_time=TodayAt(DailyAutoStartTime,now_value);
   if(now_value < start_time)
      return;

   const string day_key=TradingDayKey(now_value);
   if(day_key == g_daily_auto_start_key)
      return;

   g_daily_auto_start_key=day_key;
   if(g_allow_buy || g_allow_sell)
      return;

   g_allow_buy=true;
   g_allow_sell=true;
   RefreshPanel(true);
  }
double PipDivisor()
  {
   return((_Digits == 3 || _Digits == 5) ? 10.0 : 1.0);
  }

double CurrentSpreadPoints()
  {
   double ask_price=0.0;
   double bid_price=0.0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_ASK,ask_price) || !SymbolInfoDouble(_Symbol,SYMBOL_BID,bid_price))
      return(0.0);
   return((ask_price - bid_price) / _Point);
  }

int VolumeDigits(const double step)
  {
   string step_text=DoubleToString(step,8);
   int end_index=StringLen(step_text) - 1;
   while(end_index >= 0 && StringGetCharacter(step_text,end_index) == '0')
      end_index--;
   const int dot_index=StringFind(step_text,".");
   if(dot_index < 0 || end_index <= dot_index)
      return(0);
   return(end_index - dot_index);
  }

double NormalizeVolumeToSymbol(double volume)
  {
   const double min_volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double max_volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   const double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   const int digits=MathMax(DigitsLot,VolumeDigits(step));

   volume=MathMin(volume,MathMin(Maxlot,max_volume));
   volume=MathMax(volume,min_volume);
   if(step > 0.0)
      volume=MathRound(volume / step) * step;
   return(NormalizeDouble(volume,digits));
  }

double NormalizePriceToSymbol(double price)
  {
   const double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick_size > 0.0)
      price=MathRound(price / tick_size) * tick_size;
   return(NormalizeDouble(price,_Digits));
  }

int BrokerMinDistancePoints()
  {
   const long freeze_level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   const long stop_level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   return((int)MathMax(freeze_level,stop_level) + 1);
  }

bool IsHedgingAccount()
  {
   return((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

void ResetStats(EAStats &stats)
  {
   ZeroMemory(stats);
   stats.buy_highest_any    = 0.0;
   stats.buy_lowest_position= 0.0;
   stats.sell_highest_position=0.0;
   stats.sell_lowest_any    = 0.0;
   stats.buy_pending_price  = 0.0;
   stats.sell_pending_price = 0.0;
   stats.buy_pending_ticket = 0;
   stats.sell_pending_ticket= 0;
  }

void CollectStats(EAStats &stats)
  {
   ResetStats(stats);

   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;

      const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume=PositionGetDouble(POSITION_VOLUME);
      const double profit=PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      const datetime open_time=(datetime)PositionGetInteger(POSITION_TIME);

      if(type == POSITION_TYPE_BUY)
        {
         stats.buy_positions++;
         stats.buy_lots+=volume;
         stats.buy_profit+=profit;
         stats.buy_weighted_sum+=open_price * volume;
         if(open_price > stats.buy_highest_any || stats.buy_highest_any == 0.0)
            stats.buy_highest_any=open_price;
         if(open_price < stats.buy_lowest_position || stats.buy_lowest_position == 0.0)
            stats.buy_lowest_position=open_price;
         if(open_time > stats.last_buy_open_time)
            stats.last_buy_open_time=open_time;
        }
      else if(type == POSITION_TYPE_SELL)
        {
         stats.sell_positions++;
         stats.sell_lots+=volume;
         stats.sell_profit+=profit;
         stats.sell_weighted_sum+=open_price * volume;
         if(open_price > stats.sell_highest_position || stats.sell_highest_position == 0.0)
            stats.sell_highest_position=open_price;
         if(open_price < stats.sell_lowest_any || stats.sell_lowest_any == 0.0)
            stats.sell_lowest_any=open_price;
         if(open_time > stats.last_sell_open_time)
            stats.last_sell_open_time=open_time;
        }
     }

   for(int i=OrdersTotal()-1; i>=0; --i)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != Magic)
         continue;

      const ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      const double open_price=OrderGetDouble(ORDER_PRICE_OPEN);

      if(type == ORDER_TYPE_BUY_STOP)
        {
         stats.buy_pending++;
         if(open_price > stats.buy_highest_any || stats.buy_highest_any == 0.0)
            stats.buy_highest_any=open_price;
         if(ticket > stats.buy_pending_ticket)
           {
            stats.buy_pending_ticket=ticket;
            stats.buy_pending_price=open_price;
           }
        }
      else if(type == ORDER_TYPE_SELL_STOP)
        {
         stats.sell_pending++;
         if(open_price < stats.sell_lowest_any || stats.sell_lowest_any == 0.0)
            stats.sell_lowest_any=open_price;
         if(ticket > stats.sell_pending_ticket)
           {
            stats.sell_pending_ticket=ticket;
            stats.sell_pending_price=open_price;
           }
        }
     }

   if(stats.buy_lots > 0.0)
      stats.buy_avg_price=NormalizePriceToSymbol(stats.buy_weighted_sum / stats.buy_lots);
   if(stats.sell_lots > 0.0)
      stats.sell_avg_price=NormalizePriceToSymbol(stats.sell_weighted_sum / stats.sell_lots);
   stats.total_profit=stats.buy_profit + stats.sell_profit;
  }

double CalculateDepositBase()
  {
   double deposit_sum=0.0;
   if(!HistorySelect(0,TimeCurrent()))
      return(100.0);

   const int deals_total=(int)HistoryDealsTotal();
   for(int i=0; i<deals_total; ++i)
     {
      const ulong deal_ticket=HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      const ENUM_DEAL_TYPE deal_type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket,DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BALANCE && deal_type != DEAL_TYPE_CREDIT)
         continue;
      const double deal_profit=HistoryDealGetDouble(deal_ticket,DEAL_PROFIT);
      if(deal_profit > 0.0)
         deposit_sum+=deal_profit;
     }

   if(deposit_sum <= 0.0)
      deposit_sum=100.0;
   return(deposit_sum);
  }

double CalculateClosedProfit(const datetime from_time,const datetime to_time,const long magic_filter,const bool current_symbol_only)
  {
   double total=0.0;
   if(!HistorySelect(from_time,to_time))
      return(0.0);

   const int deals_total=(int)HistoryDealsTotal();
   for(int i=0; i<deals_total; ++i)
     {
      const ulong deal_ticket=HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;

      const ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
         continue;

      if(current_symbol_only && HistoryDealGetString(deal_ticket,DEAL_SYMBOL) != _Symbol)
         continue;

      if(magic_filter != -1 && (long)HistoryDealGetInteger(deal_ticket,DEAL_MAGIC) != magic_filter)
         continue;

      total+=HistoryDealGetDouble(deal_ticket,DEAL_PROFIT);
      total+=HistoryDealGetDouble(deal_ticket,DEAL_SWAP);
      total+=HistoryDealGetDouble(deal_ticket,DEAL_COMMISSION);
     }

   return(total);
  }

string TradingDayKey(const datetime now_value)
  {
   return(TimeToString(now_value,TIME_DATE));
  }

double TodayClosedProfit(const datetime now_value)
  {
   return(CalculateClosedProfit(TodayAt("00:00",now_value),TimeCurrent(),Magic,true));
  }

double TodayProgressProfit(const datetime now_value,const EAStats &stats)
  {
   return(TodayClosedProfit(now_value) + stats.total_profit);
  }

bool HasOpenPositions(const EAStats &stats)
  {
   return((stats.buy_positions + stats.sell_positions) > 0);
  }

bool HasActiveExposure(const EAStats &stats)
  {
   return(HasOpenPositions(stats) || (stats.buy_pending + stats.sell_pending) > 0);
  }

void RefreshDailyLocks(const datetime now_value,const EAStats &stats)
  {
   const string day_key=TradingDayKey(now_value);
   if(day_key != g_today_key)
     {
      g_today_key=day_key;
      g_daily_target_locked=false;
      g_daily_target_hit_value=0.0;
     }

   if(!EnableDailyProfitTarget || DailyProfitTarget <= 0.0)
     {
      g_daily_target_locked=false;
      g_daily_target_hit_value=0.0;
      return;
     }

   if(g_daily_target_locked)
      return;

   const double today_progress=TodayProgressProfit(now_value,stats);
   if(today_progress >= DailyProfitTarget)
     {
      g_daily_target_locked=true;
      g_daily_target_hit_value=today_progress;
     }
  }

void RefreshDailyLossBase(const datetime now_value)
  {
   const string day_key=TradingDayKey(now_value);
   if(day_key == g_daily_loss_key && g_daily_loss_base_equity > 0.0)
      return;

   g_daily_loss_key=day_key;
   g_daily_loss_base_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_daily_loss_base_equity <= 0.0)
      g_daily_loss_base_equity=AccountInfoDouble(ACCOUNT_BALANCE);
   g_daily_loss_triggered=false;
   g_daily_loss_alerted=false;
  }

bool CheckDailyLossStop(const bool show_alert)
  {
   if(!EnableDailyLossStop || DailyLossStopPct <= 0.0)
      return(false);

   const datetime now_value=ReferenceNow();
   RefreshDailyLossBase(now_value);
   if(g_daily_loss_triggered || g_daily_loss_base_equity <= 0.0)
      return(false);

   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const double loss_pct=(g_daily_loss_base_equity - equity) / g_daily_loss_base_equity * 100.0;
   if(loss_pct < DailyLossStopPct)
      return(false);

   g_daily_loss_triggered=true;
   g_allow_buy=false;
   g_allow_sell=false;
   DeleteEaPendingOrders();
   CloseAllAccountPositions();

   string pct_text=DoubleToString(DailyLossStopPct,2);
   if(MathAbs(DailyLossStopPct - MathRound(DailyLossStopPct)) < 0.0001)
      pct_text=IntegerToString((int)MathRound(DailyLossStopPct));
   const string message="您好，检测到行情不适合，已亏损" + pct_text + "%，已经平仓停止交易！";
   Print(message," base_equity=",DoubleToString(g_daily_loss_base_equity,2),
         " equity=",DoubleToString(equity,2),
         " loss_pct=",DoubleToString(loss_pct,2));
   if(show_alert && !g_daily_loss_alerted)
     {
      Alert(message);
      g_daily_loss_alerted=true;
     }
   return(true);
  }

double AccountProfitForPanel()
  {
   return(AccountInfoDouble(ACCOUNT_PROFIT));
  }

int CountPositionsWithComment(const string comment_text,const ENUM_POSITION_TYPE type)
  {
   int count=0;
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;
      if(PositionGetString(POSITION_COMMENT) == comment_text)
         count++;
     }
   return(count);
  }

double SumExtremePositionProfits(const ENUM_POSITION_TYPE type,const bool positive,const int count)
  {
   if(count <= 0)
      return(0.0);

   double values[];
   ArrayResize(values,0);

   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      const double profit=PositionGetDouble(POSITION_PROFIT);
      if(positive && profit >= 0.0)
        {
         const int size=ArraySize(values);
         ArrayResize(values,size + 1);
         values[size]=profit;
        }
      if(!positive && profit < 0.0)
        {
         const int size=ArraySize(values);
         ArrayResize(values,size + 1);
         values[size]=-profit;
        }
     }

   if(ArraySize(values) == 0)
      return(0.0);

   ArraySort(values);
   double sum=0.0;
   int taken=0;
   for(int i=ArraySize(values)-1; i>=0 && taken<count; --i)
     {
      sum+=values[i];
      taken++;
     }
   return(sum);
  }

ulong FindExtremePositionTicket(const ENUM_POSITION_TYPE type,const bool positive)
  {
   bool found=false;
   double best_profit=0.0;
   ulong best_ticket=0;

   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      const double profit=PositionGetDouble(POSITION_PROFIT);
      if(positive)
        {
         if(profit < 0.0)
            continue;
         if(!found || profit > best_profit)
           {
            found=true;
            best_profit=profit;
            best_ticket=ticket;
           }
        }
      else
        {
         if(profit >= 0.0)
            continue;
         if(!found || profit < best_profit)
           {
            found=true;
            best_profit=profit;
            best_ticket=ticket;
           }
        }
     }

   return(best_ticket);
  }

double FindExtremePositionLot(const ENUM_POSITION_TYPE type,const bool positive)
  {
   const ulong ticket=FindExtremePositionTicket(type,positive);
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return(0.0);
   return(PositionGetDouble(POSITION_VOLUME));
  }

void CloseExtremePositions(const ENUM_POSITION_TYPE type,int count,const bool positive)
  {
   while(count > 0)
     {
      const ulong ticket=FindExtremePositionTicket(type,positive);
      if(ticket == 0)
         break;
      ClosePositionTicket(ticket);
      count--;
     }
  }

ulong FindNewestPositionTicket(const ENUM_POSITION_TYPE type,const bool current_symbol_only,const long magic_filter)
  {
   ulong newest_ticket=0;
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(current_symbol_only && PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(magic_filter != -1 && (long)PositionGetInteger(POSITION_MAGIC) != magic_filter)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;
      if(ticket > newest_ticket)
         newest_ticket=ticket;
     }
   return(newest_ticket);
  }

bool CloseByPair(const ulong position_ticket,const ulong opposite_ticket)
  {
   MqlTradeRequest request={};
   MqlTradeResult  result={};
   request.action=TRADE_ACTION_CLOSE_BY;
   request.position=position_ticket;
   request.position_by=opposite_ticket;
   request.magic=Magic;

   return(CheckOrderSendResult(OrderSend(request,result),result,"CloseByPair"));
  }

void CloseOppositePairs()
  {
   while(true)
     {
      const ulong buy_ticket=FindNewestPositionTicket(POSITION_TYPE_BUY,true,Magic);
      const ulong sell_ticket=FindNewestPositionTicket(POSITION_TYPE_SELL,true,Magic);
      if(buy_ticket == 0 || sell_ticket == 0)
         break;

      if(CloseByPair(buy_ticket,sell_ticket))
         continue;
      if(CloseByPair(sell_ticket,buy_ticket))
         continue;
      break;
     }
  }

bool TradeRetcodeOk(const uint retcode)
  {
   return(retcode == TRADE_RETCODE_DONE ||
          retcode == TRADE_RETCODE_DONE_PARTIAL ||
          retcode == TRADE_RETCODE_PLACED ||
          retcode == TRADE_RETCODE_NO_CHANGES);
  }

bool CheckTradeResult(const bool request_ok,const string action)
  {
   const uint retcode=g_trade.ResultRetcode();
   if(request_ok && TradeRetcodeOk(retcode))
      return(true);

   PrintFormat("%s failed on %s: request_ok=%s retcode=%u detail=%s",
               action,
               _Symbol,
               request_ok ? "true" : "false",
               retcode,
               g_trade.ResultRetcodeDescription());
   return(false);
  }

bool CheckOrderSendResult(const bool request_ok,const MqlTradeResult &result,const string action)
  {
   if(request_ok && TradeRetcodeOk(result.retcode))
      return(true);

   PrintFormat("%s failed on %s: request_ok=%s retcode=%u order=%I64u deal=%I64u",
               action,
               _Symbol,
               request_ok ? "true" : "false",
               result.retcode,
               result.order,
               result.deal);
   return(false);
  }

bool ClosePositionTicket(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return(false);
   return(CheckTradeResult(g_trade.PositionClose(ticket),"ClosePositionTicket"));
  }

bool DeletePendingOrder(const ulong ticket)
  {
   if(ticket == 0)
      return(false);
   return(CheckTradeResult(g_trade.OrderDelete(ticket),"DeletePendingOrder"));
  }

void DeleteEaPendingOrders()
  {
   for(int i=OrdersTotal()-1; i>=0; --i)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != Magic)
         continue;

      const ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;
      DeletePendingOrder(ticket);
     }
  }

bool ModifyPendingPrice(const ulong ticket,const double new_price)
  {
   if(ticket == 0 || !OrderSelect(ticket))
      return(false);

   MqlTradeRequest request={};
   MqlTradeResult  result={};
   request.action=TRADE_ACTION_MODIFY;
   request.order=ticket;
   request.symbol=OrderGetString(ORDER_SYMBOL);
   request.magic=(ulong)OrderGetInteger(ORDER_MAGIC);
   request.price=new_price;
   request.sl=0.0;
   request.tp=0.0;
   request.type_time=ORDER_TIME_GTC;
   request.expiration=0;

   return(CheckOrderSendResult(OrderSend(request,result),result,"ModifyPendingPrice"));
  }

void CloseEaOrders(const int direction,const bool use_pairs,const bool arm_cooldown)
  {
   if(use_pairs && direction == 0)
      CloseOppositePairs();

   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;

      const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(direction == 1 && type != POSITION_TYPE_BUY)
         continue;
      if(direction == -1 && type != POSITION_TYPE_SELL)
         continue;
      ClosePositionTicket(ticket);
     }

   for(int i=OrdersTotal()-1; i>=0; --i)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != Magic)
         continue;

      const ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(direction == 1 && type != ORDER_TYPE_BUY_STOP)
         continue;
      if(direction == -1 && type != ORDER_TYPE_SELL_STOP)
         continue;
      if(direction == 0 && type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;
      DeletePendingOrder(ticket);
     }

   if(arm_cooldown && NextTime > 0)
      g_pause_until=TimeCurrent() + NextTime;
  }

void ClosePositionsByProfitState(const bool close_profit)
  {
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;

      const double profit=PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(close_profit && profit >= 0.0)
         ClosePositionTicket(ticket);
      if(!close_profit && profit < 0.0)
         ClosePositionTicket(ticket);
     }
  }

void CloseCurrentSymbolPositions()
  {
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ClosePositionTicket(ticket);
     }
  }

void CloseAllAccountPositions()
  {
   for(int i=PositionsTotal()-1; i>=0; --i)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      ClosePositionTicket(ticket);
     }
  }

string DeepSeekStateText(const DeepSeekMarketState state)
  {
   if(state == DeepSeekState_Warning)
      return("WARNING");
   if(state == DeepSeekState_Trend)
      return("TREND");
   return("RANGE");
  }

string DeepSeekDirectionText(const DeepSeekDirection direction)
  {
   if(direction == DeepSeekDirection_Up)
      return("UP");
   if(direction == DeepSeekDirection_Down)
      return("DOWN");
   return("NONE");
  }

bool DeepSeekIsConfigured()
  {
   return(StringLen(DeepSeekApiKey) > 0 && DeepSeekApiKey != "在这里填写API_KEY" && StringLen(DeepSeekUrl) > 0);
  }

bool DeepSeekResultFresh()
  {
   if(!g_deepseek_result_ok || g_deepseek_last_success <= 0)
      return(false);
   return((TimeCurrent() - g_deepseek_last_success) <= DeepSeekResultValidMinutes * 60);
  }

bool DeepSeekBlocksNewCycle()
  {
   return(!DeepSeekResultFresh() || g_deepseek_state == DeepSeekState_Trend);
  }

bool DeepSeekBlocksGrid()
  {
   return(DeepSeekResultFresh() && g_deepseek_state == DeepSeekState_Trend);
  }

bool IsEaStrategyOrderComment(const string comment_text)
  {
   return(comment_text == GOLDKING_ORDER_COMMENT_PRIMARY || comment_text == GOLDKING_ORDER_COMMENT_SECONDARY);
  }

void DeleteEaStrategyPendingOrders()
  {
   for(int i=OrdersTotal()-1; i>=0; --i)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != Magic)
         continue;

      const ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP)
         continue;
      if(!IsEaStrategyOrderComment(OrderGetString(ORDER_COMMENT)))
         continue;

      DeletePendingOrder(ticket);
     }
  }

string JsonEscape(const string text)
  {
   string escaped="";
   for(int i=0; i<StringLen(text); ++i)
     {
      const ushort ch=StringGetCharacter(text,i);
      if(ch == '\\')
         escaped+="\\\\";
      else if(ch == '"')
         escaped+="\\\"";
      else if(ch == '\n')
         escaped+="\\n";
      else if(ch == '\r')
         escaped+="\\r";
      else if(ch == '\t')
         escaped+="\\t";
      else
         escaped+=ShortToString(ch);
     }
   return(escaped);
  }

string DeepSeekCandleJson(const ENUM_TIMEFRAMES timeframe,const int bars)
  {
   string json="[";
   for(int shift=bars; shift>=1; --shift)
     {
      const datetime bar_time=iTime(_Symbol,timeframe,shift);
      if(bar_time <= 0)
         continue;
      if(StringLen(json) > 1)
         json+=",";
      json+="{\"time\":\"" + TimeToString(bar_time,TIME_DATE|TIME_MINUTES) + "\",";
      json+="\"open\":" + DoubleToString(iOpen(_Symbol,timeframe,shift),_Digits) + ",";
      json+="\"high\":" + DoubleToString(iHigh(_Symbol,timeframe,shift),_Digits) + ",";
      json+="\"low\":" + DoubleToString(iLow(_Symbol,timeframe,shift),_Digits) + ",";
      json+="\"close\":" + DoubleToString(iClose(_Symbol,timeframe,shift),_Digits) + "}";
     }
   json+="]";
   return(json);
  }

double DeepSeekFloatingLossPct(const EAStats &stats)
  {
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0 || stats.total_profit >= 0.0)
      return(0.0);
   return(MathAbs(stats.total_profit) / equity * 100.0);
  }

string BuildDeepSeekPayload(const EAStats &stats)
  {
   const string system_prompt=
      "你是一个客观的 XAUUSD 网格策略行情状态识别引擎。\n"
      "我给你提供以下数据帮我分析出是震荡、单边预警还是单边\n"
      "主要判断周期为 M15，辅助为 H1 和 M5。\n"
      "必须返回且只能返回这四个字段：state、confidence、direction、reason_code。\n"
      "完整格式示例：{\"state\":\"RANGE\",\"confidence\":80,\"direction\":\"NONE\",\"reason_code\":\"RANGE_STABLE\"}";

   string market="{";
   market+="\"symbol\":\"" + JsonEscape(_Symbol) + "\",";
   market+="\"m5\":" + DeepSeekCandleJson(PERIOD_M5,24) + ",";
   market+="\"m15\":" + DeepSeekCandleJson(PERIOD_M15,48) + ",";
   market+="\"h1\":" + DeepSeekCandleJson(PERIOD_H1,24);
   market+="}";

   string payload="{";
   payload+="\"model\":\"" + JsonEscape(DeepSeekModel) + "\",";
   payload+="\"thinking\":{\"type\":\"disabled\"},";
   payload+="\"response_format\":{\"type\":\"json_object\"},";
   payload+="\"temperature\":0.0,";
   payload+="\"top_p\":1.0,";
   payload+="\"messages\":[";
   const string user_content=
      "请根据下面市场数据返回完整JSON，禁止省略任何字段。\n"
      "只能从这些枚举取值：state=RANGE|WARNING|TREND；direction=UP|DOWN|NONE；reason_code=RANGE_STABLE|BREAKOUT_WARNING|TREND_CONTINUATION|INSUFFICIENT_DATA。\n"
      "返回模板：{\"state\":\"RANGE\",\"confidence\":0,\"direction\":\"NONE\",\"reason_code\":\"INSUFFICIENT_DATA\"}\n"
      "市场数据：" + market;
   payload+="{\"role\":\"system\",\"content\":\"" + JsonEscape(system_prompt) + "\"},";
   payload+="{\"role\":\"user\",\"content\":\"" + JsonEscape(user_content) + "\"}";
   payload+="]}";
   return(payload);
  }

bool ExtractJsonStringField(const string json,const string field,string &value)
  {
   const string key="\"" + field + "\"";
   int pos=StringFind(json,key,0);
   if(pos < 0)
      return(false);
   pos=StringFind(json,":",pos + StringLen(key));
   if(pos < 0)
      return(false);
   pos=StringFind(json,"\"",pos + 1);
   if(pos < 0)
      return(false);

   string out="";
   bool escaped=false;
   for(int i=pos + 1; i<StringLen(json); ++i)
     {
      const ushort ch=StringGetCharacter(json,i);
      if(escaped)
        {
         out+="\\" + ShortToString(ch);
         escaped=false;
         continue;
        }
      if(ch == '\\')
        {
         escaped=true;
         continue;
        }
      if(ch == '"')
        {
         value=JsonUnescape(out);
         return(true);
        }
      out+=ShortToString(ch);
     }
   return(false);
  }

bool ExtractJsonNumberField(const string json,const string field,double &value)
  {
   const string key="\"" + field + "\"";
   int pos=StringFind(json,key,0);
   if(pos < 0)
      return(false);
   pos=StringFind(json,":",pos + StringLen(key));
   if(pos < 0)
      return(false);
   pos++;
   while(pos < StringLen(json) && StringGetCharacter(json,pos) == ' ')
      pos++;

   string number="";
   for(int i=pos; i<StringLen(json); ++i)
     {
      const ushort ch=StringGetCharacter(json,i);
      if((ch >= '0' && ch <= '9') || ch == '-' || ch == '+')
         number+=ShortToString(ch);
      else if(ch == '.')
         number+=".";
      else
         break;
     }
   if(StringLen(number) == 0)
      return(false);
   value=StringToDouble(number);
   return(true);
  }

string JsonUnescape(const string text)
  {
   string out="";
   bool escaped=false;
   for(int i=0; i<StringLen(text); ++i)
     {
      const ushort ch=StringGetCharacter(text,i);
      if(!escaped)
        {
         if(ch == '\\')
           {
            escaped=true;
            continue;
           }
         out+=ShortToString(ch);
         continue;
        }

      if(ch == 'n')
         out+="\n";
      else if(ch == 'r')
         out+="\r";
      else if(ch == 't')
         out+="\t";
      else
         out+=ShortToString(ch);
      escaped=false;
     }
   return(out);
  }

DeepSeekMarketState DeepSeekStateFromText(const string text)
  {
   if(text == "WARNING")
      return(DeepSeekState_Warning);
   if(text == "TREND")
      return(DeepSeekState_Trend);
   return(DeepSeekState_Range);
  }

DeepSeekDirection DeepSeekDirectionFromText(const string text)
  {
   if(text == "UP")
      return(DeepSeekDirection_Up);
   if(text == "DOWN")
      return(DeepSeekDirection_Down);
   return(DeepSeekDirection_None);
  }

bool ParseDeepSeekResponse(const string response,DeepSeekResult &parsed)
  {
   parsed.ok=false;
   parsed.state=DeepSeekState_Range;
   parsed.confidence=0;
   parsed.direction=DeepSeekDirection_None;
   parsed.reason_code="";
   parsed.raw_json=response;

   string content="";
   if(!ExtractJsonStringField(response,"content",content))
      return(false);

   string state_text="";
   string direction_text="";
   string reason_code="";
   double confidence=0.0;
   if(!ExtractJsonStringField(content,"state",state_text))
      return(false);
   if(!ExtractJsonNumberField(content,"confidence",confidence))
      confidence=0.0;
   if(!ExtractJsonStringField(content,"direction",direction_text))
      direction_text="NONE";
   if(!ExtractJsonStringField(content,"reason_code",reason_code))
      reason_code="INSUFFICIENT_DATA";

   if(state_text != "RANGE" && state_text != "WARNING" && state_text != "TREND")
      return(false);
   if(direction_text != "UP" && direction_text != "DOWN" && direction_text != "NONE")
      return(false);

   parsed.ok=true;
   parsed.state=DeepSeekStateFromText(state_text);
   parsed.direction=DeepSeekDirectionFromText(direction_text);
   parsed.confidence=(int)MathMax(0.0,MathMin(100.0,confidence));
   parsed.reason_code=reason_code;
   return(true);
  }

bool CallDeepSeekApi(const EAStats &stats,DeepSeekResult &parsed)
  {
   parsed.ok=false;
   parsed.state=DeepSeekState_Range;
   parsed.confidence=0;
   parsed.direction=DeepSeekDirection_None;
   parsed.reason_code="";
   parsed.raw_json="";
   g_deepseek_http_status=0;
   g_deepseek_raw_response="";

   if(!DeepSeekIsConfigured())
     {
      g_deepseek_status_reason="DeepSeek API Key未配置";
      g_deepseek_last_ai_state="ERROR";
      Print("DeepSeek请求跳过：",g_deepseek_status_reason);
      return(false);
     }

   const string payload=BuildDeepSeekPayload(stats);
   char post_data[];
   StringToCharArray(payload,post_data,0,WHOLE_ARRAY,CP_UTF8);
   if(ArraySize(post_data) > 0)
      ArrayResize(post_data,ArraySize(post_data)-1);

   char result[];
   string result_headers="";
   const string headers="Content-Type: application/json\r\nAuthorization: Bearer " + DeepSeekApiKey + "\r\n";

   Print("DeepSeek请求：M5新收盘K线，payload字节=",ArraySize(post_data),", 当前状态=",DeepSeekStateText(g_deepseek_state));
   if(DeepSeekPrintPayload)
      Print("DeepSeek请求完整payload：",payload);
   ResetLastError();
   const int status=WebRequest("POST",DeepSeekUrl,headers,DeepSeekTimeoutMs,post_data,result,result_headers);
   g_deepseek_http_status=status;
   g_deepseek_raw_response=CharArrayToString(result,0,-1,CP_UTF8);
   Print("DeepSeek HTTP状态码：",status,", LastError=",GetLastError());
   Print("DeepSeek AI原始返回：",g_deepseek_raw_response);

   if(status != 200)
     {
      g_deepseek_status_reason="DeepSeek HTTP非200：" + IntegerToString(status);
      g_deepseek_last_ai_state="ERROR";
      return(false);
     }

   if(!ParseDeepSeekResponse(g_deepseek_raw_response,parsed))
     {
      g_deepseek_status_reason="DeepSeek JSON解析失败";
      g_deepseek_last_ai_state="ERROR";
      return(false);
     }

   Print("DeepSeek解析状态：state=",DeepSeekStateText(parsed.state),
         ", confidence=",parsed.confidence,
         ", direction=",DeepSeekDirectionText(parsed.direction),
         ", reason_code=",parsed.reason_code);
   return(true);
  }

void ApplyDeepSeekDebounce(const DeepSeekResult &parsed)
  {
   if(!parsed.ok)
      return;

   const DeepSeekMarketState old_state=g_deepseek_state;
   g_deepseek_state=parsed.state;
   g_deepseek_warning_hits=0;
   g_deepseek_trend_hits=0;
   g_deepseek_nontrend_hits=0;
   g_deepseek_range_hits=0;

   g_deepseek_result_ok=true;
   g_deepseek_last_success=TimeCurrent();
   g_deepseek_confidence=parsed.confidence;
   g_deepseek_direction=parsed.direction;
   g_deepseek_reason_code=parsed.reason_code;
   g_deepseek_last_ai_state=DeepSeekStateText(parsed.state);
   g_deepseek_status_reason="AI=" + DeepSeekStateText(parsed.state) +
                            " 直接生效" +
                            " 置信度=" + IntegerToString(parsed.confidence) +
                            " 原因=" + parsed.reason_code;

   if(old_state != g_deepseek_state)
      Print("DeepSeek状态切换：",DeepSeekStateText(old_state)," -> ",DeepSeekStateText(g_deepseek_state),
            "，",g_deepseek_status_reason);
   if(old_state != g_deepseek_state || g_deepseek_trend_manage_direction != g_deepseek_direction)
     {
      g_deepseek_trend_last_manage_m5=0;
      g_deepseek_trend_manage_direction=DeepSeekDirection_None;
      g_deepseek_trend_extreme_price=0.0;
      g_deepseek_trend_manage_reason="TREND状态重置";
     }
  }

void UpdateDeepSeekOnNewM5(const EAStats &stats)
  {
   const datetime closed_m5=iTime(_Symbol,PERIOD_M5,1);
   if(closed_m5 <= 0 || closed_m5 == g_deepseek_last_m5_bar)
      return;
   g_deepseek_last_m5_bar=closed_m5;

   g_deepseek_m15_atr_ratio=CalculateM15AtrRatio();
   DeepSeekResult parsed;
   if(CallDeepSeekApi(stats,parsed))
      ApplyDeepSeekDebounce(parsed);
   else
      g_deepseek_result_ok=false;
  }

double CalculateM15AtrRatio()
  {
   if(DeepSeekAtrPeriod <= 0 || DeepSeekAtrAverageBars <= 1)
      return(1.0);

   const int handle=iATR(_Symbol,PERIOD_M15,DeepSeekAtrPeriod);
   if(handle == INVALID_HANDLE)
      return(1.0);

   double values[];
   ArraySetAsSeries(values,true);
   const int copied=CopyBuffer(handle,0,1,DeepSeekAtrAverageBars + 1,values);
   IndicatorRelease(handle);
   if(copied < DeepSeekAtrAverageBars + 1 || values[0] <= 0.0)
      return(1.0);

   double sum=0.0;
   for(int i=1; i<copied; ++i)
      sum+=values[i];
   const double avg=sum / (copied - 1);
   if(avg <= 0.0)
      return(1.0);
   return(values[0] / avg);
  }

double CalculateCurrentM15Atr()
  {
   if(DeepSeekAtrPeriod <= 0)
      return(0.0);

   const int handle=iATR(_Symbol,PERIOD_M15,DeepSeekAtrPeriod);
   if(handle == INVALID_HANDLE)
      return(0.0);

   double value[];
   ArraySetAsSeries(value,true);
   const int copied=CopyBuffer(handle,0,1,1,value);
   IndicatorRelease(handle);
   if(copied < 1 || value[0] <= 0.0)
      return(0.0);
   return(value[0]);
  }

int DeepSeekAdjustedGridDistance(const int base_points)
  {
   if(!DeepSeekResultFresh() || g_deepseek_state != DeepSeekState_Warning)
      return(base_points);
   double multiplier=MathMax(DeepSeekWarningMinDistanceMultiplier,g_deepseek_m15_atr_ratio);
   multiplier=MathMin(multiplier,MathMax(DeepSeekWarningMaxDistanceMultiplier,DeepSeekWarningMinDistanceMultiplier));
   return((int)MathCeil(base_points * multiplier));
  }

bool ApplyDeepSeekTrendRiskManagement(EAStats &stats)
  {
   if(!DeepSeekResultFresh() || g_deepseek_state != DeepSeekState_Trend || g_deepseek_direction == DeepSeekDirection_None)
     {
      g_deepseek_trend_manage_direction=DeepSeekDirection_None;
      g_deepseek_trend_extreme_price=0.0;
      g_deepseek_trend_manage_reason="非TREND";
      return(false);
     }

   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(DeepSeekTrendMaxLossPct > 0.0 && equity > 0.0 && stats.total_profit < 0.0)
     {
      const double loss_pct=MathAbs(stats.total_profit) / equity * 100.0;
      if(loss_pct >= DeepSeekTrendMaxLossPct)
        {
         g_deepseek_trend_manage_reason="TREND亏损达到 " + DoubleToString(loss_pct,2) + "%，全部止损";
         Print("DeepSeek TREND风控：",g_deepseek_trend_manage_reason);
         CloseEaOrders(0,false,true);
         CollectStats(stats);
         return(true);
        }
     }

   const ENUM_POSITION_TYPE adverse_type=(g_deepseek_direction == DeepSeekDirection_Up ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
   const int adverse_count=(adverse_type == POSITION_TYPE_SELL ? stats.sell_positions : stats.buy_positions);
   if(adverse_count <= 0)
     {
      g_deepseek_trend_manage_reason="TREND无逆势仓";
      return(false);
     }

   const datetime closed_m5=iTime(_Symbol,PERIOD_M5,1);
   if(closed_m5 <= 0 || closed_m5 == g_deepseek_trend_last_manage_m5)
      return(false);
   g_deepseek_trend_last_manage_m5=closed_m5;

   const double price=(g_deepseek_direction == DeepSeekDirection_Up ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   const double atr=MathMax(CalculateCurrentM15Atr(),_Point);
   const double retrace_distance=atr * MathMax(DeepSeekTrendRetraceAtrMultiplier,0.0);
   const double continue_distance=atr * MathMax(DeepSeekTrendContinueAtrMultiplier,0.0);

   if(g_deepseek_trend_manage_direction != g_deepseek_direction || g_deepseek_trend_extreme_price <= 0.0)
     {
      g_deepseek_trend_manage_direction=g_deepseek_direction;
      g_deepseek_trend_extreme_price=price;
      g_deepseek_trend_manage_reason="TREND极值初始化";
      return(false);
     }

   bool trend_continue=false;
   bool trend_retrace=false;
   if(g_deepseek_direction == DeepSeekDirection_Up)
     {
      trend_continue=(price >= g_deepseek_trend_extreme_price + continue_distance);
      trend_retrace=(g_deepseek_trend_extreme_price - price >= retrace_distance);
      if(price > g_deepseek_trend_extreme_price)
         g_deepseek_trend_extreme_price=price;
     }
   else
     {
      trend_continue=(price <= g_deepseek_trend_extreme_price - continue_distance);
      trend_retrace=(price - g_deepseek_trend_extreme_price >= retrace_distance);
      if(price < g_deepseek_trend_extreme_price)
         g_deepseek_trend_extreme_price=price;
     }

   if(!trend_continue && !trend_retrace)
     {
      g_deepseek_trend_manage_reason="TREND等待回撤/推进";
      return(false);
     }

   const ulong adverse_ticket=FindExtremePositionTicket(adverse_type,false);
   if(adverse_ticket == 0)
     {
      g_deepseek_trend_manage_reason="TREND逆势仓暂无亏损单";
      return(false);
     }

   const string action_reason=(trend_retrace ? "逢回撤减逆势仓" : "趋势继续减逆势仓");
   g_deepseek_trend_manage_reason=action_reason;
   Print("DeepSeek TREND风控：",action_reason,
         "，方向=",DeepSeekDirectionText(g_deepseek_direction),
         "，ticket=",adverse_ticket,
         "，ATR=",DoubleToString(atr,_Digits));
   if(ClosePositionTicket(adverse_ticket))
     {
      CollectStats(stats);
      return(true);
     }
   return(false);
  }

bool IsTradingEnvironmentOk(const EAStats &stats,string &reason)
  {
   reason="";

   if(!IsHedgingAccount())
     {
      reason="MT5净额账户不支持该EA，请切换到对冲账户";
      return(false);
     }

   if((int)AccountInfoInteger(ACCOUNT_LEVERAGE) < Leverage)
     {
      reason="杠杆低于限制";
      return(false);
     }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      reason="终端未启用交易";
      return(false);
     }

   long trade_mode=SYMBOL_TRADE_MODE_DISABLED;
   if(!SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE,trade_mode))
     {
      reason="无法读取品种交易状态";
      return(false);
     }

   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
     {
      reason="当前品种禁止开新单";
      return(false);
     }

   if(IsStopped())
     {
      reason="EA已停止";
      return(false);
     }

   if(stats.buy_positions + stats.sell_positions >= Totals)
     {
      reason="达到最大持仓数";
      return(false);
     }

   if(CurrentSpreadPoints() > MaxSpread)
     {
      reason="点差超限";
      return(false);
     }

   return(true);
  }

void UpdateLimitLines()
  {
   const datetime now_value=ReferenceNow();
   const bool limit_window_active=IsInWindow(Limit_StartTime,Limit_StopTime,now_value);
   const string buy_line=g_panel_prefix + "limit_buy_add";
   const string sell_line=g_panel_prefix + "limit_sell_add";

   if(limit_window_active && On_top_of_this_price_not_Buy_order > 0.0)
     {
      if(ObjectFind(0,buy_line) < 0)
         ObjectCreate(0,buy_line,OBJ_HLINE,0,0,On_top_of_this_price_not_Buy_order);
      ObjectSetDouble(0,buy_line,OBJPROP_PRICE,On_top_of_this_price_not_Buy_order);
      ObjectSetInteger(0,buy_line,OBJPROP_COLOR,clr1);
      ObjectSetInteger(0,buy_line,OBJPROP_STYLE,STYLE_DASH);
     }
   else if(ObjectFind(0,buy_line) >= 0)
      ObjectDelete(0,buy_line);

   if(limit_window_active && On_under_of_this_price_not_Sell_order > 0.0)
     {
      if(ObjectFind(0,sell_line) < 0)
         ObjectCreate(0,sell_line,OBJ_HLINE,0,0,On_under_of_this_price_not_Sell_order);
      ObjectSetDouble(0,sell_line,OBJPROP_PRICE,On_under_of_this_price_not_Sell_order);
      ObjectSetInteger(0,sell_line,OBJPROP_COLOR,clr2);
      ObjectSetInteger(0,sell_line,OBJPROP_STYLE,STYLE_DASH);
     }
   else if(ObjectFind(0,sell_line) >= 0)
      ObjectDelete(0,sell_line);
  }

void UpdateAverageLines(const EAStats &stats)
  {
   const string buy_line=g_panel_prefix + "avg_buy";
   const string sell_line=g_panel_prefix + "avg_sell";

   if(stats.buy_positions > 0 && stats.buy_avg_price > 0.0)
     {
      if(ObjectFind(0,buy_line) < 0)
         ObjectCreate(0,buy_line,OBJ_HLINE,0,0,stats.buy_avg_price);
      ObjectSetDouble(0,buy_line,OBJPROP_PRICE,stats.buy_avg_price);
      ObjectSetInteger(0,buy_line,OBJPROP_COLOR,clr1);
      ObjectSetInteger(0,buy_line,OBJPROP_WIDTH,2);
     }
   else if(ObjectFind(0,buy_line) >= 0)
      ObjectDelete(0,buy_line);

   if(stats.sell_positions > 0 && stats.sell_avg_price > 0.0)
     {
      if(ObjectFind(0,sell_line) < 0)
         ObjectCreate(0,sell_line,OBJ_HLINE,0,0,stats.sell_avg_price);
      ObjectSetDouble(0,sell_line,OBJPROP_PRICE,stats.sell_avg_price);
      ObjectSetInteger(0,sell_line,OBJPROP_COLOR,clr2);
      ObjectSetInteger(0,sell_line,OBJPROP_WIDTH,2);
     }
   else if(ObjectFind(0,sell_line) >= 0)
      ObjectDelete(0,sell_line);
  }

bool ShouldUsePrimaryParameters(const EAStats &stats)
  {
   if(Money == 0.0)
      return(true);
   return(stats.total_profit > g_second_loss_threshold);
  }

bool AllowBuyOrderByPriceLimit(const EAStats &stats,const double target_price,const bool limit_window_active)
  {
   if(stats.buy_positions == 0)
      return(true);
   if(!limit_window_active)
      return(true);
   if(On_top_of_this_price_not_Buy_order == 0.0)
      return(true);
   return(target_price < On_top_of_this_price_not_Buy_order);
  }

bool AllowSellOrderByPriceLimit(const EAStats &stats,const double target_price,const bool limit_window_active)
  {
   if(stats.sell_positions == 0)
      return(true);
   if(!limit_window_active)
      return(true);
   if(On_under_of_this_price_not_Sell_order == 0.0)
      return(true);
   return(target_price > On_under_of_this_price_not_Sell_order);
  }

bool CanOpenThisCycle(const bool is_buy,const EAStats &stats)
  {
   if(OpenMode == OpenMode_NoDelay || OpenMode == OpenMode_Bar)
      return(true);
   const datetime last_open=is_buy ? stats.last_buy_open_time : stats.last_sell_open_time;
   return((TimeCurrent() - last_open) >= sleep);
  }

bool TryProtectiveCloseBySide(const EAStats &stats)
  {
   const int buy_ss_count=CountPositionsWithComment(GOLDKING_ORDER_COMMENT_SECONDARY,POSITION_TYPE_BUY);
   const int sell_ss_count=CountPositionsWithComment(GOLDKING_ORDER_COMMENT_SECONDARY,POSITION_TYPE_SELL);

   if((buy_ss_count < 1 || !HomeopathyCloseAll) &&
      stats.buy_profit > g_max_loss_close_all &&
      stats.sell_profit > g_max_loss_close_all)
     {
      const double buy_target=Profit ? StopProfit * stats.buy_positions : StopProfit;
      const double sell_target=Profit ? StopProfit * stats.sell_positions : StopProfit;

      if(stats.buy_positions > 0 && stats.buy_profit > buy_target)
        {
         CloseEaOrders(1,false,false);
         return(true);
        }

      if(stats.sell_positions > 0 && stats.sell_profit > sell_target)
        {
         CloseEaOrders(-1,false,false);
         return(true);
        }
     }

   if(HomeopathyCloseAll && (buy_ss_count > 0 || sell_ss_count > 0) && stats.total_profit >= CloseAll)
     {
      CloseEaOrders(0,true,true);
      return(true);
     }

   if(stats.total_profit >= CloseAll &&
      (stats.buy_profit <= g_max_loss_close_all || stats.sell_profit <= g_max_loss_close_all))
     {
      CloseEaOrders(0,true,true);
      return(true);
     }
   return(false);
  }

bool ApplyCloseBuySellProtection(const EAStats &stats)
  {
   if(!CloseBuySell)
      return(false);

   const double buy_delta=SumExtremePositionProfits(POSITION_TYPE_BUY,true,1) - SumExtremePositionProfits(POSITION_TYPE_BUY,false,2);
   if(g_buy_protection_peak < buy_delta)
      g_buy_protection_peak=buy_delta;
   if(g_buy_protection_peak > 0.0 && buy_delta > 0.0)
     {
      const double biggest_win_lot=FindExtremePositionLot(POSITION_TYPE_BUY,true);
      if(stats.buy_lots > biggest_win_lot * 3.0 + stats.sell_lots && stats.buy_positions > 3)
        {
         CloseExtremePositions(POSITION_TYPE_BUY,1,true);
         CloseExtremePositions(POSITION_TYPE_BUY,2,false);
         g_buy_protection_peak=0.0;
         g_sell_protection_peak=0.0;
         return(true);
        }
     }

   const double sell_delta=SumExtremePositionProfits(POSITION_TYPE_SELL,true,1) - SumExtremePositionProfits(POSITION_TYPE_SELL,false,2);
   if(g_sell_protection_peak < sell_delta)
      g_sell_protection_peak=sell_delta;
   if(g_sell_protection_peak > 0.0 && sell_delta > 0.0)
     {
      const double biggest_win_lot=FindExtremePositionLot(POSITION_TYPE_SELL,true);
      if(stats.sell_lots > biggest_win_lot * 3.0 + stats.buy_lots && stats.sell_positions > 3)
        {
         CloseExtremePositions(POSITION_TYPE_SELL,1,true);
         CloseExtremePositions(POSITION_TYPE_SELL,2,false);
         g_buy_protection_peak=0.0;
         g_sell_protection_peak=0.0;
         return(true);
        }
     }
   return(false);
  }

bool TryAutoCloseLogic(const EAStats &stats)
  {
   if(Over && stats.total_profit >= CloseAll)
     {
      CloseEaOrders(0,true,true);
      return(true);
     }

   if(!Over)
     {
      if(TryProtectiveCloseBySide(stats))
         return(true);
     }

   if(StopLoss != 0.0 && stats.total_profit <= g_stop_loss_limit)
     {
      CloseEaOrders(0,false,true);
      return(true);
     }

   return(ApplyCloseBuySellProtection(stats));
  }

void TryPlacePendingOrders(const EAStats &stats,const bool allow_buy,const bool allow_sell)
  {
   const bool block_new_cycle=DeepSeekBlocksNewCycle();
   const bool block_grid=DeepSeekBlocksGrid();
   const int min_distance=BrokerMinDistancePoints();
   const int first_step=MathMax(FirstStep,min_distance);
   const int buy_grid_min=MathMax(DeepSeekAdjustedGridDistance(MinDistance),min_distance);
   const int sell_grid_min=MathMax(DeepSeekAdjustedGridDistance(MinDistance),min_distance);
   const int buy_grid_two_min=MathMax(DeepSeekAdjustedGridDistance(TwoMinDistance),min_distance);
   const int sell_grid_two_min=MathMax(DeepSeekAdjustedGridDistance(TwoMinDistance),min_distance);
   const int buy_grid_step=MathMax(DeepSeekAdjustedGridDistance(Step),min_distance);
   const int sell_grid_step=MathMax(DeepSeekAdjustedGridDistance(Step),min_distance);
   const int buy_grid_two_step=MathMax(DeepSeekAdjustedGridDistance(TwoStep),min_distance);
   const int sell_grid_two_step=MathMax(DeepSeekAdjustedGridDistance(TwoStep),min_distance);
   const bool primary_params=ShouldUsePrimaryParameters(stats);
   const bool limit_window_active=IsInWindow(Limit_StartTime,Limit_StopTime,ReferenceNow());
   const bool lots_equal=(MathAbs(stats.buy_lots - stats.sell_lots) < 0.0000001);
   const bool buy_rebalance=(stats.buy_lots > 0.0 && stats.sell_lots / stats.buy_lots > 3.0 && stats.sell_lots - stats.buy_lots > 0.2);
   const bool sell_rebalance=(stats.sell_lots > 0.0 && stats.buy_lots / stats.sell_lots > 3.0 && stats.buy_lots - stats.sell_lots > 0.2);
   const double ask_price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double bid_price=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   bool can_process_cycle=true;
   datetime current_bar=0;
   if(OpenMode == OpenMode_Bar)
     {
      current_bar=iTime(_Symbol,TimeZone,0);
      can_process_cycle=(current_bar != 0 && current_bar != g_last_open_bar_time);
     }
   if(!can_process_cycle)
      return;

   if(allow_buy && stats.buy_pending == 0 && stats.buy_profit > g_max_loss_limit &&
      !((stats.buy_positions == 0 && block_new_cycle) || (stats.buy_positions > 0 && block_grid)))
     {
      double target_price=0.0;
      if(stats.buy_positions == 0)
         target_price=NormalizePriceToSymbol(ask_price + first_step * _Point);
      else
        {
         target_price=NormalizePriceToSymbol(ask_price + (primary_params ? buy_grid_min : buy_grid_two_min) * _Point);
         if(stats.buy_lowest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.buy_lowest_position - (primary_params ? buy_grid_step : buy_grid_two_step) * _Point))
            target_price=NormalizePriceToSymbol(ask_price + (primary_params ? buy_grid_step : buy_grid_two_step) * _Point);
        }

      const bool buy_condition=
         (stats.buy_positions == 0) ||
         (stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_grid_step * _Point) && buy_rebalance && primary_params) ||
         (stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_grid_two_step * _Point) && buy_rebalance && !primary_params && Money != 0.0) ||
         (stats.buy_lowest_position != 0.0 && target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - buy_grid_step * _Point) && primary_params) ||
         (stats.buy_lowest_position != 0.0 && target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - buy_grid_two_step * _Point) && !primary_params && Money != 0.0) ||
         (Homeopathy && stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_grid_step * _Point) && lots_equal);

      if(buy_condition && AllowBuyOrderByPriceLimit(stats,target_price,limit_window_active) && CanOpenThisCycle(true,stats))
        {
         double volume=(stats.buy_positions == 0) ? lot : (stats.buy_positions * PlusLot + lot * MathPow(K_Lot,stats.buy_positions));
         volume=NormalizeVolumeToSymbol(volume);
         const bool use_secondary_comment=
            ((stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_grid_step * _Point) && buy_rebalance && primary_params) ||
             (stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_grid_two_step * _Point) && buy_rebalance && !primary_params && Money != 0.0) ||
             (Homeopathy && stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_grid_step * _Point) && lots_equal));

         CheckTradeResult(g_trade.BuyStop(volume,target_price,_Symbol,0.0,0.0,ORDER_TIME_GTC,0,use_secondary_comment ? GOLDKING_ORDER_COMMENT_SECONDARY : GOLDKING_ORDER_COMMENT_PRIMARY),"BuyStop");
        }
     }

   if(allow_sell && stats.sell_pending == 0 && stats.sell_profit > g_max_loss_limit &&
      !((stats.sell_positions == 0 && block_new_cycle) || (stats.sell_positions > 0 && block_grid)))
     {
      double target_price=0.0;
      if(stats.sell_positions == 0)
         target_price=NormalizePriceToSymbol(bid_price - first_step * _Point);
      else
        {
         target_price=NormalizePriceToSymbol(bid_price - (primary_params ? sell_grid_min : sell_grid_two_min) * _Point);
         if(stats.sell_highest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.sell_highest_position + (primary_params ? sell_grid_step : sell_grid_two_step) * _Point))
            target_price=NormalizePriceToSymbol(bid_price - (primary_params ? sell_grid_step : sell_grid_two_step) * _Point);
        }

      const bool sell_condition=
         (stats.sell_positions == 0) ||
         (stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_grid_step * _Point) && sell_rebalance && primary_params) ||
         (stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_grid_two_step * _Point) && sell_rebalance && !primary_params && Money != 0.0) ||
         (stats.sell_highest_position != 0.0 && target_price >= NormalizePriceToSymbol(stats.sell_highest_position + sell_grid_step * _Point) && primary_params) ||
         (stats.sell_highest_position != 0.0 && target_price >= NormalizePriceToSymbol(stats.sell_highest_position + sell_grid_two_step * _Point) && !primary_params && Money != 0.0) ||
         (Homeopathy && stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_grid_step * _Point) && lots_equal);

      if(sell_condition && AllowSellOrderByPriceLimit(stats,target_price,limit_window_active) && CanOpenThisCycle(false,stats))
        {
         double volume=(stats.sell_positions == 0) ? lot : (stats.sell_positions * PlusLot + lot * MathPow(K_Lot,stats.sell_positions));
         volume=NormalizeVolumeToSymbol(volume);
         const bool use_secondary_comment=
            ((stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_grid_step * _Point) && sell_rebalance && primary_params) ||
             (stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_grid_two_step * _Point) && sell_rebalance && !primary_params && Money != 0.0) ||
             (Homeopathy && stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_grid_step * _Point) && lots_equal));

         CheckTradeResult(g_trade.SellStop(volume,target_price,_Symbol,0.0,0.0,ORDER_TIME_GTC,0,use_secondary_comment ? GOLDKING_ORDER_COMMENT_SECONDARY : GOLDKING_ORDER_COMMENT_PRIMARY),"SellStop");
        }
     }

   if(OpenMode == OpenMode_Bar && current_bar != 0)
      g_last_open_bar_time=current_bar;
  }

void TryTrailPendingOrders(const EAStats &stats,const bool allow_buy,const bool allow_sell)
  {
   const bool block_new_cycle=DeepSeekBlocksNewCycle();
   const bool block_grid=DeepSeekBlocksGrid();
   const int min_distance=BrokerMinDistancePoints();
   const int first_step=MathMax(FirstStep,min_distance);
   const int grid_primary_min=MathMax(DeepSeekAdjustedGridDistance(MinDistance),min_distance);
   const int grid_second_min=MathMax(DeepSeekAdjustedGridDistance(TwoMinDistance),min_distance);
   const int grid_primary_step=MathMax(DeepSeekAdjustedGridDistance(Step),min_distance);
   const int grid_second_step=MathMax(DeepSeekAdjustedGridDistance(TwoStep),min_distance);
   const bool primary_params=ShouldUsePrimaryParameters(stats);
   const bool buy_rebalance=(stats.buy_lots > 0.0 && stats.sell_lots / stats.buy_lots > 3.0 && stats.sell_lots - stats.buy_lots > 0.2);
   const bool sell_rebalance=(stats.sell_lots > 0.0 && stats.buy_lots / stats.sell_lots > 3.0 && stats.buy_lots - stats.sell_lots > 0.2);
   const double ask_price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double bid_price=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(allow_buy && stats.buy_pending_ticket > 0 &&
      !((stats.buy_positions == 0 && block_new_cycle) || (stats.buy_positions > 0 && block_grid)))
     {
      double target_price=(stats.buy_positions == 0) ? NormalizePriceToSymbol(ask_price + first_step * _Point)
                                                     : NormalizePriceToSymbol(ask_price + (primary_params ? grid_primary_min : grid_second_min) * _Point);
      if(stats.buy_positions > 0 && stats.buy_lowest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.buy_lowest_position - (primary_params ? grid_primary_step : grid_second_step) * _Point))
         target_price=NormalizePriceToSymbol(ask_price + (primary_params ? grid_primary_step : grid_second_step) * _Point);

      const bool trail_ok=
         primary_params ?
         (target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - grid_primary_step * _Point) || stats.buy_lowest_position == 0.0 || (buy_rebalance && stats.buy_positions == 0) || target_price >= NormalizePriceToSymbol(stats.buy_highest_any + grid_primary_step * _Point))
         :
         (target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - grid_second_step * _Point) || stats.buy_lowest_position == 0.0 || (buy_rebalance && stats.buy_positions == 0) || target_price >= NormalizePriceToSymbol(stats.buy_highest_any + grid_second_step * _Point));

      if(stats.buy_pending_price != 0.0 && NormalizePriceToSymbol(stats.buy_pending_price - StepTrallOrders * _Point) > target_price && trail_ok)
         ModifyPendingPrice(stats.buy_pending_ticket,target_price);
     }

   if(allow_sell && stats.sell_pending_ticket > 0 &&
      !((stats.sell_positions == 0 && block_new_cycle) || (stats.sell_positions > 0 && block_grid)))
     {
      double target_price=(stats.sell_positions == 0) ? NormalizePriceToSymbol(bid_price - first_step * _Point)
                                                      : NormalizePriceToSymbol(bid_price - (primary_params ? grid_primary_min : grid_second_min) * _Point);
      if(stats.sell_positions > 0 && stats.sell_highest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.sell_highest_position + (primary_params ? grid_primary_step : grid_second_step) * _Point))
         target_price=NormalizePriceToSymbol(bid_price - (primary_params ? grid_primary_step : grid_second_step) * _Point);

      const bool trail_ok=
         primary_params ?
         (target_price >= NormalizePriceToSymbol(stats.sell_highest_position + grid_primary_step * _Point) || stats.sell_highest_position == 0.0 || (sell_rebalance && stats.sell_positions == 0) || target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - grid_primary_step * _Point))
         :
         (target_price >= NormalizePriceToSymbol(stats.sell_highest_position + grid_second_step * _Point) || stats.sell_highest_position == 0.0 || (sell_rebalance && stats.sell_positions == 0) || target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - grid_second_step * _Point));

      if(stats.sell_pending_price != 0.0 && NormalizePriceToSymbol(stats.sell_pending_price + StepTrallOrders * _Point) < target_price && trail_ok)
         ModifyPendingPrice(stats.sell_pending_ticket,target_price);
     }
  }

void ExecuteStrategy()
  {
   EAStats stats;
   CollectStats(stats);
   UpdateDeepSeekOnNewM5(stats);
   const datetime now_value=ReferenceNow();
   RefreshDailyLocks(now_value,stats);

   const bool session_after_stop=IsTradingSessionAfterStop(now_value);
   const bool session_ok=IsTradingSessionOpen(now_value);
   const bool wrap_up_blocked=IsDailyWrapUpWindow(now_value);
   const bool target_locked=g_daily_target_locked;

   if((session_after_stop || wrap_up_blocked || target_locked) && (stats.buy_pending > 0 || stats.sell_pending > 0))
     {
      DeleteEaPendingOrders();
      CollectStats(stats);
      RefreshDailyLocks(now_value,stats);
        }

   UpdateLimitLines();
   UpdateAverageLines(stats);

   string env_reason="";
   const bool env_ok=IsTradingEnvironmentOk(stats,env_reason);

   bool allow_buy=g_allow_buy;
   bool allow_sell=g_allow_sell;

   if(Over && stats.buy_positions == 0)
      allow_buy=false;
   if(Over && stats.sell_positions == 0)
      allow_sell=false;

   if(g_pause_until > TimeCurrent())
     {
      allow_buy=false;
      allow_sell=false;
     }

   if(!session_ok || session_after_stop || wrap_up_blocked || target_locked)
     {
      allow_buy=false;
      allow_sell=false;
     }

   if(!env_ok)
     {
      allow_buy=false;
      allow_sell=false;
     }

   if(TryAutoCloseLogic(stats))
     {
      RefreshPanel(true);
      return;
     }

   if(DeepSeekBlocksGrid())
     {
      if(stats.buy_pending > 0 || stats.sell_pending > 0)
        {
         DeleteEaStrategyPendingOrders();
         CollectStats(stats);
        }
      ApplyDeepSeekTrendRiskManagement(stats);
      RefreshPanel(true);
      return;
     }

   if(DeepSeekBlocksNewCycle() && stats.buy_positions + stats.sell_positions == 0)
     {
      if(stats.buy_pending > 0 || stats.sell_pending > 0)
        {
         DeleteEaStrategyPendingOrders();
         CollectStats(stats);
        }
      RefreshPanel(true);
      return;
     }

   if(OpenMode == OpenMode_Bar && !(allow_buy || allow_sell))
     {
      const datetime current_bar=iTime(_Symbol,TimeZone,0);
      if(current_bar != 0 && current_bar != g_last_open_bar_time)
         g_last_open_bar_time=current_bar;
     }

   if(allow_buy || allow_sell)
      TryPlacePendingOrders(stats,allow_buy,allow_sell);

   if(allow_buy || allow_sell)
      TryTrailPendingOrders(stats,allow_buy,allow_sell);

   RefreshPanel(false);
  }

double UiScale()
  {
   const long chart_width=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   const long dpi=TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   double scale=1.0;

   if(dpi >= 192)
      scale=1.02;
   else if(dpi >= 160)
      scale=1.00;
   else if(dpi <= 96)
      scale=0.96;

   if(chart_width <= 900)
      scale=MathMin(scale,0.82);
   else if(chart_width <= 1100)
      scale=MathMin(scale,0.88);
   else if(chart_width <= 1280)
      scale=MathMin(scale,0.92);
   else if(chart_width >= 2400)
      scale=MathMin(MathMax(scale,1.0),1.04);

   return(MathMax(0.78,MathMin(scale,1.04)));
  }

double UiFontScale()
  {
   const long chart_width=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   const long dpi=TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   double scale=1.0;

   if(dpi >= 192)
      scale=1.02;
   else if(dpi >= 160)
      scale=1.00;
   else if(dpi <= 96)
      scale=0.96;

   if(chart_width <= 900)
      scale=MathMin(scale,0.80);
   else if(chart_width <= 1100)
      scale=MathMin(scale,0.86);
   else if(chart_width <= 1280)
      scale=MathMin(scale,0.92);

   return(MathMax(0.78,MathMin(scale,1.03)));
  }

int ScalePx(const int value)
  {
   return((int)MathRound(value * UiScale()));
  }

int ScaleFont(const int value)
  {
   return((int)MathRound(value * UiFontScale()));
  }

void BuildPanelMetrics(PanelMetrics &m)
  {
   const long chart_width=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   const int available_w=(int)MathMax(300.0,(double)chart_width - ScalePx(24));

   m.margin_x       = ScalePx(12);
   m.margin_y       = ScalePx(12);
   m.width          = (int)MathMax(300.0,MathMin((double)ScalePx(560),(double)available_w));
   m.pad            = ScalePx(14);
   m.section_gap    = ScalePx(10);
   m.header_h       = ScalePx(54);
   m.row_h          = ScalePx(18);
   m.gap            = ScalePx(10);
   m.button_h       = ScalePx(42);
   m.inner_w        = m.width - m.pad * 2;
   m.half_w         = (m.inner_w - m.gap) / 2;
   m.compact        = (m.width < ScalePx(500));
   m.card_status_h  = (m.compact ? ScalePx(264) : ScalePx(262));
   m.card_metrics_h = (m.compact ? ScalePx(238) : ScalePx(122));
   m.card_actions_h = ScalePx(160);
   m.button_font    = ScaleFont(15);
   m.font_xs        = ScaleFont(9);
   m.font_sm        = ScaleFont(10);
   m.font_md        = ScaleFont(12);
   m.font_lg        = ScaleFont(22);
   m.toggle_w       = ScalePx(52);
   m.panel_h        = m.header_h + m.card_status_h + m.section_gap + m.card_metrics_h + m.section_gap + m.card_actions_h + ScalePx(28);
  }
void EnsureRectangle(const string name,const int x,const int y,const int w,const int h,const color bg,const color border,const int corner)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
  }

void EnsureLabel(const string name,const string text,const int x,const int y,const int font_size,const color clr,const int corner,const string font="Microsoft YaHei")
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
  }

void EnsureButton(const string name,const string text,const int x,const int y,const int w,const int h,const color bg,const color fg,const int corner)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,ScaleFont(9));
   ObjectSetString(0,name,OBJPROP_FONT,"Microsoft YaHei");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
  }

string BoolText(const bool enabled,const string on_text,const string off_text)
  {
   return(enabled ? on_text : off_text);
  }

string FormatSignedMoney(const double value)
  {
   const string sign=(value > 0.0) ? "+" : "";
   return(sign + DoubleToString(value,2));
  }

string FormatPercent(const double value)
  {
   return(DoubleToString(value,2) + "%");
  }

string FormatPanelMoment(const datetime when,const datetime now_value)
  {
   if(when <= 0)
      return("--");

   MqlDateTime stamp={};
   MqlDateTime now_stamp={};
   TimeToStruct(when,stamp);
   TimeToStruct(now_value,now_stamp);

   if(stamp.year == now_stamp.year && stamp.mon == now_stamp.mon && stamp.day == now_stamp.day)
      return(StringFormat("%02d:%02d",stamp.hour,stamp.min));

   return(StringFormat("%02d-%02d %02d:%02d",stamp.mon,stamp.day,stamp.hour,stamp.min));
  }


string WrapUpPauseReason(const EAStats &stats)
  {
   if(!IsDailyWrapUpWindow(ReferenceNow()))
      return("");

   return(HasOpenPositions(stats) ? "日内收尾阶段，等待全部平仓"
                                  : "日内收尾阶段，今日停止交易");
  }

string SessionStateText(const datetime now_value,const EAStats &stats)
  {
   if(!EnableTradingSessionWindow)
      return("已关闭");

   if(IsTradingSessionAfterStop(now_value))
      return(HasOpenPositions(stats) ? "结束时间已到，等待平仓" : "今日已收工");

   if(!IsTradingSessionOpen(now_value))
      return("未到工作时间");

   return("工作时段内");
  }

string WrapUpStateText(const EAStats &stats)
  {
   if(!EnableDailyWrapUpPhase)
      return("已关闭");

   const string slot=DailyWrapUpStartTime + "-" + DailyWrapUpStopTime;
   if(!IsDailyWrapUpWindow(ReferenceNow()))
      return("服" + slot + " 未触发");

   return(HasOpenPositions(stats) ? "服" + slot + " 等待平仓" : "服" + slot + " 已收尾");
  }

string GoalStateText(const double target_progress_display)
  {
   if(!EnableDailyProfitTarget)
      return("已关闭");

   if(DailyProfitTarget <= 0.0)
      return("金额<=0");

   if(g_daily_target_locked)
      return("已达 " + FormatSignedMoney(MathMax(target_progress_display,g_daily_target_hit_value)) + " / +" + DoubleToString(DailyProfitTarget,2));

   return("进度 " + FormatSignedMoney(target_progress_display) + " / +" + DoubleToString(DailyProfitTarget,2));
  }


string EntryStateText(const string stop_reason)
  {
   if(g_allow_buy && g_allow_sell)
      return("允许");

   if(!g_allow_buy && !g_allow_sell)
      return("手动停止");

   if(stop_reason != "")
      return("暂停");

   return("部分允许");
  }

string CloseReasonText()
  {
   string reason="";
   EAStats stats;
   CollectStats(stats);
   const datetime now_value=ReferenceNow();
   RefreshDailyLocks(now_value,stats);

   if(g_daily_target_locked)
      return(HasOpenPositions(stats) ? "今日盈利达标，等待全部平仓" : "今日盈利目标已达成");

   const string wrap_reason=WrapUpPauseReason(stats);
   if(wrap_reason != "")
      return(wrap_reason);

   if(IsTradingSessionAfterStop(now_value))
      return(HasOpenPositions(stats) ? "已到结束时间，等待全部平仓" : "今日已收工");

   if(!IsTradingSessionOpen(now_value))
      return("等待工作时段开始");

   if(!g_allow_buy && !g_allow_sell)
      return("已手动停止交易");

   if(g_pause_until > TimeCurrent())
      return("冷却中 " + IntegerToString((int)(g_pause_until - TimeCurrent())) + " 秒");

   if(!IsTradingEnvironmentOk(stats,reason))
      return(reason);

   return("");
  }

string ClipText(const string text,const int max_chars)
  {
   if(max_chars <= 0)
      return("");
   if(StringLen(text) <= max_chars)
      return(text);
   if(max_chars <= 3)
      return(StringSubstr(text,0,max_chars));
   return(StringSubstr(text,0,max_chars - 3) + "...");
  }

string TimeframeLabel(const ENUM_TIMEFRAMES timeframe)
  {
   const string enum_text=EnumToString(timeframe);
   if(StringFind(enum_text,"PERIOD_",0) == 0)
      return(StringSubstr(enum_text,7));
   return(enum_text);
  }

void DrawPanel(const EAStats &stats)
  {
   PanelMetrics m;
   BuildPanelMetrics(m);
   const int corner=CORNER_LEFT_UPPER;
   const color panel_bg=C'8,13,18';
   const color panel_bg_2=C'12,18,25';
   const color panel_border=C'42,52,66';
   const color card_bg=C'14,20,28';
   const color card_border=C'38,48,61';
   const color muted=C'150,158,171';
   const color soft=C'200,207,216';
   const color white=C'246,249,252';
   const color green=C'73,211,91';
   const color green_dark=C'27,145,55';
   const color blue=C'61,151,255';
   const color gold=C'255,202,63';
   const color red=C'207,45,50';
   const color red_dark=C'154,34,38';

   const int x=m.margin_x;
   const int y0=m.margin_y;
   const int inner_x=x + m.pad;
   const int inner_w=m.inner_w;
   const int panel_right=x + m.width;
   const int title_x=inner_x + ScalePx(66);
   const datetime now_value=ReferenceNow();
   RefreshDailyLocks(now_value,stats);
   RefreshDailyLossBase(now_value);

   const double today_profit=TodayClosedProfit(now_value);
   const double today_progress=TodayProgressProfit(now_value,stats);
   const double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const string currency=AccountInfoString(ACCOUNT_CURRENCY);
   const string symbol_text=_Symbol;
   const string symbol_desc=(StringFind(_Symbol,"XAU",0) >= 0 ? "黄金/美元" : "当前交易品种");
   const bool manual_trading_on=(g_allow_buy || g_allow_sell);
   const bool trading_allowed=manual_trading_on && CloseReasonText() == "";
   const string status_main=(trading_allowed ? "正常工作" : (manual_trading_on ? "等待条件" : "暂停交易"));
   const string status_sub=(trading_allowed ? "EA运行中，策略已激活" : (manual_trading_on ? "EA运行中，等待交易条件" : "EA运行中，已手动停止"));
   const string main_button_text=(manual_trading_on ? "停止交易" : "开始交易");
   const string trade_line=(manual_trading_on ? "当前状态：交易进行中，点击可停止交易" : "当前状态：交易已停止，点击可开始交易");
   const string trade_line_compact=(manual_trading_on ? "交易中，点击停止" : "已停止，点击开始");
   const bool deepseek_configured=DeepSeekIsConfigured();
   const bool deepseek_fresh=DeepSeekResultFresh();
   const string deepseek_activity=(!deepseek_configured ? "未配置" : (deepseek_fresh ? "正常" : (g_deepseek_result_ok ? "结果过期" : "异常/等待")));
   const color deepseek_activity_color=(!deepseek_configured ? gold : (deepseek_fresh ? green : red));
   const color deepseek_state_color=(g_deepseek_state == DeepSeekState_Trend ? red : (g_deepseek_state == DeepSeekState_Warning ? gold : green));
   const string deepseek_effective_text="实际 " + DeepSeekStateText(g_deepseek_state);
   const string deepseek_return_text="AI返回 " + g_deepseek_last_ai_state + " " + IntegerToString(g_deepseek_confidence) + "% " + DeepSeekDirectionText(g_deepseek_direction);
   const string deepseek_http_text="HTTP " + IntegerToString(g_deepseek_http_status) + "  上次 " + FormatPanelMoment(g_deepseek_last_success,now_value);
   const double deepseek_grid_multiplier=MathMin(MathMax(DeepSeekWarningMinDistanceMultiplier,g_deepseek_m15_atr_ratio),
                                                 MathMax(DeepSeekWarningMaxDistanceMultiplier,DeepSeekWarningMinDistanceMultiplier));
   const string deepseek_atr_text="M15 ATR倍率 x" + DoubleToString(g_deepseek_m15_atr_ratio,2) +
                                  "  补仓倍数 " + DoubleToString(deepseek_grid_multiplier,2);
   const string deepseek_count_text="防抖 关闭，AI返回即生效";
   const string deepseek_trend_text="TREND管理 " + ClipText(g_deepseek_trend_manage_reason,m.compact ? 28 : 48);
   const string deepseek_reason_text=ClipText(g_deepseek_reason_code + " " + g_deepseek_status_reason,m.compact ? 34 : 58);
   const double daily_base=(g_daily_loss_base_equity > 0.0 ? g_daily_loss_base_equity : equity);
   const double daily_equity_pct=(daily_base > 0.0 ? (equity - daily_base) / daily_base * 100.0 : 0.0);
   const bool daily_equity_profit=(daily_equity_pct > 0.0001);
   const bool daily_equity_loss=(daily_equity_pct < -0.0001);
   const string daily_equity_text=(daily_equity_profit ? "盈利 " + FormatSignedMoney(daily_equity_pct) + "%"
                                                      : "回撤 " + DoubleToString(MathMax(0.0,-daily_equity_pct),2) + "%");
   const int exposure_count=stats.buy_positions + stats.sell_positions;

   int closed_count=0;
   const datetime day_start=TodayAt("00:00",now_value);
   if(HistorySelect(day_start,TimeCurrent()))
     {
      for(int i=0; i<HistoryDealsTotal(); ++i)
        {
         const ulong deal_ticket=HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if((long)HistoryDealGetInteger(deal_ticket,DEAL_MAGIC) != Magic)
            continue;
         if(HistoryDealGetString(deal_ticket,DEAL_SYMBOL) != _Symbol)
            continue;
         const long entry=HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
            closed_count++;
        }
     }

   ObjectDelete(0,g_panel_prefix + "toggle_panel");
   ObjectDelete(0,g_panel_prefix + "stop_all");
   ObjectDelete(0,g_panel_prefix + "stop_buy");
   ObjectDelete(0,g_panel_prefix + "stop_sell");
   ObjectDelete(0,g_panel_prefix + "close_symbol");
   ObjectDelete(0,g_panel_prefix + "close_profit");
   ObjectDelete(0,g_panel_prefix + "close_loss");
   ObjectDelete(0,g_panel_prefix + "close_buy");
   ObjectDelete(0,g_panel_prefix + "close_sell");
   ObjectDelete(0,g_panel_prefix + "close_ea");
   ObjectDelete(0,g_panel_prefix + "close_account");
   ObjectDelete(0,g_panel_prefix + "metric_1_c");
   ObjectDelete(0,g_panel_prefix + "metric_2_c");
   ObjectDelete(0,g_panel_prefix + "metric_3_c");
   ObjectDelete(0,g_panel_prefix + "clock_icon");
   ObjectDelete(0,g_panel_prefix + "clock");

   EnsureRectangle(g_panel_prefix + "panel_shadow",x + ScalePx(2),y0 + ScalePx(2),m.width,m.panel_h,C'3,6,10',C'3,6,10',corner);
   EnsureRectangle(g_panel_prefix + "panel",x,y0,m.width,m.panel_h,panel_bg,panel_border,corner);
   EnsureRectangle(g_panel_prefix + "panel_glow",x + ScalePx(2),y0 + ScalePx(2),m.width - ScalePx(4),m.panel_h - ScalePx(4),panel_bg_2,panel_border,corner);

   const int title_font=(m.compact ? ScaleFont(19) : ScaleFont(23));
   const int tf_font=(m.compact ? ScaleFont(20) : ScaleFont(24));
   const int header_title_x=(m.compact ? inner_x + ScalePx(46) : title_x);
   const int header_tf_x=header_title_x + (m.compact ? ScalePx(132) : ScalePx(166));
   EnsureLabel(g_panel_prefix + "menu_icon","☰",inner_x + ScalePx(8),y0 + ScalePx(15),ScaleFont(20),muted,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "title","多米诺量化",header_title_x,y0 + ScalePx(12),title_font,C'165,220,255',corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "title_tf","D2",header_tf_x,y0 + ScalePx(12),tf_font,blue,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "min_icon","—",panel_right - ScalePx(76),y0 + ScalePx(12),ScaleFont(19),muted,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "close_icon","×",panel_right - ScalePx(40),y0 + ScalePx(11),ScaleFont(23),muted,corner,"Microsoft YaHei UI");

   int y=y0 + m.header_h;
   EnsureRectangle(g_panel_prefix + "status_card",inner_x,y,inner_w,m.card_status_h,card_bg,card_border,corner);
   const int status_icon_x=inner_x + (m.compact ? ScalePx(14) : ScalePx(20));
   const int status_text_x=inner_x + (m.compact ? ScalePx(74) : ScalePx(92));
   const int symbol_x=inner_x + inner_w / 2 + (m.compact ? ScalePx(26) : ScalePx(52));
   const int status_main_font=(m.compact ? ScaleFont(18) : ScaleFont(22));
   const int symbol_font=(m.compact ? ScaleFont(18) : ScaleFont(22));
   EnsureLabel(g_panel_prefix + "status_title","工作状态",inner_x + ScalePx(18),y + ScalePx(16),m.font_md,muted,corner);
   EnsureLabel(g_panel_prefix + "status_circle","○",status_icon_x,y + ScalePx(42),ScaleFont(36),green,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "status_check","✓",status_icon_x + ScalePx(15),y + ScalePx(54),ScaleFont(23),green,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "status_main",status_main,status_text_x,y + ScalePx(46),status_main_font,trading_allowed ? green : gold,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "status_sub",status_sub,status_text_x,y + ScalePx(78),m.font_xs,soft,corner);
   EnsureRectangle(g_panel_prefix + "status_divider",inner_x + inner_w / 2 + ScalePx(4),y + ScalePx(22),ScalePx(1),ScalePx(72),C'72,84,100',C'72,84,100',corner);
   EnsureLabel(g_panel_prefix + "symbol_title","交易品种",symbol_x,y + ScalePx(16),m.font_md,muted,corner);
   EnsureLabel(g_panel_prefix + "symbol",symbol_text,symbol_x,y + ScalePx(48),symbol_font,gold,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "symbol_desc",symbol_desc,symbol_x,y + ScalePx(78),m.font_xs,soft,corner);
   EnsureRectangle(g_panel_prefix + "deepseek_divider",inner_x + ScalePx(18),y + ScalePx(104),inner_w - ScalePx(36),ScalePx(1),C'40,50,63',C'40,50,63',corner);
   EnsureLabel(g_panel_prefix + "deepseek_title","AI风控",inner_x + ScalePx(18),y + ScalePx(116),m.font_md,muted,corner);
   EnsureLabel(g_panel_prefix + "deepseek_activity",deepseek_activity,inner_x + ScalePx(82),y + ScalePx(116),m.font_md,deepseek_activity_color,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "deepseek_effective",deepseek_effective_text,inner_x + ScalePx(18),y + ScalePx(138),m.font_sm,deepseek_state_color,corner);
   EnsureLabel(g_panel_prefix + "deepseek_return",deepseek_return_text,inner_x + ScalePx(18),y + ScalePx(158),m.font_sm,soft,corner);
   EnsureLabel(g_panel_prefix + "deepseek_http",deepseek_http_text,inner_x + ScalePx(18),y + ScalePx(178),m.font_sm,soft,corner);
   EnsureLabel(g_panel_prefix + "deepseek_atr",deepseek_atr_text,inner_x + ScalePx(18),y + ScalePx(198),m.font_sm,soft,corner);
   EnsureLabel(g_panel_prefix + "deepseek_count",deepseek_count_text,inner_x + ScalePx(18),y + ScalePx(216),m.font_sm,soft,corner);
   EnsureLabel(g_panel_prefix + "deepseek_trend",deepseek_trend_text,inner_x + ScalePx(18),y + ScalePx(234),m.font_sm,soft,corner);
   EnsureLabel(g_panel_prefix + "deepseek_reason",deepseek_reason_text,inner_x + ScalePx(18),y + ScalePx(252),m.font_sm,muted,corner);

   y+=m.card_status_h + m.section_gap;
   EnsureLabel(g_panel_prefix + "progress_title","今日进度",inner_x + ScalePx(10),y + ScalePx(0),m.font_md,muted,corner);

   const int card_y=y + ScalePx(24);
   const int card_gap=ScalePx(8);
   const int metric_value_font=(m.compact ? ScaleFont(15) : ScaleFont(17));
   const int metric_balance_font=(m.compact ? ScaleFont(14) : ScaleFont(16));

   if(m.compact)
     {
      const int compact_card_h=ScalePx(66);
      int row_y=card_y;

      EnsureRectangle(g_panel_prefix + "metric_1",inner_x + ScalePx(4),row_y,inner_w - ScalePx(8),compact_card_h,card_bg,card_border,corner);
      EnsureRectangle(g_panel_prefix + "metric_1_accent",inner_x + ScalePx(4),row_y + ScalePx(12),ScalePx(2),compact_card_h - ScalePx(24),green_dark,green_dark,corner);
      EnsureLabel(g_panel_prefix + "metric_1_t","今日进度",inner_x + ScalePx(20),row_y + ScalePx(12),m.font_sm,soft,corner);
      EnsureLabel(g_panel_prefix + "metric_1_v",FormatSignedMoney(today_progress) + " " + currency,inner_x + ScalePx(104),row_y + ScalePx(10),metric_value_font,today_progress >= 0.0 ? green : red,corner,"Microsoft YaHei UI");
      EnsureLabel(g_panel_prefix + "metric_1_s",daily_equity_text,inner_x + ScalePx(104),row_y + ScalePx(38),m.font_xs,daily_equity_loss ? red : green,corner);

      row_y+=compact_card_h + card_gap;
      EnsureRectangle(g_panel_prefix + "metric_2",inner_x + ScalePx(4),row_y,inner_w - ScalePx(8),compact_card_h,card_bg,card_border,corner);
      EnsureLabel(g_panel_prefix + "metric_2_t","今日已平",inner_x + ScalePx(20),row_y + ScalePx(12),m.font_sm,soft,corner);
      EnsureLabel(g_panel_prefix + "metric_2_v",FormatSignedMoney(today_profit) + " " + currency,inner_x + ScalePx(104),row_y + ScalePx(10),metric_value_font,blue,corner,"Microsoft YaHei UI");
      EnsureLabel(g_panel_prefix + "metric_2_s","已平仓 " + IntegerToString(closed_count) + " 笔",inner_x + ScalePx(104),row_y + ScalePx(38),m.font_xs,soft,corner);

      row_y+=compact_card_h + card_gap;
      EnsureRectangle(g_panel_prefix + "metric_3",inner_x + ScalePx(4),row_y,inner_w - ScalePx(8),compact_card_h,card_bg,card_border,corner);
      EnsureLabel(g_panel_prefix + "metric_3_t","账户余额",inner_x + ScalePx(20),row_y + ScalePx(12),m.font_sm,soft,corner);
      EnsureLabel(g_panel_prefix + "metric_3_v",DoubleToString(balance,2) + " " + currency,inner_x + ScalePx(104),row_y + ScalePx(10),metric_balance_font,gold,corner,"Microsoft YaHei UI");
      EnsureLabel(g_panel_prefix + "metric_3_s","净值 " + DoubleToString(equity,2),inner_x + ScalePx(104),row_y + ScalePx(38),m.font_xs,soft,corner);
     }
   else
     {
      const int card_w=(inner_w - ScalePx(8) - card_gap * 2) / 3;
      EnsureRectangle(g_panel_prefix + "metric_1",inner_x + ScalePx(4),card_y,card_w,m.card_metrics_h - ScalePx(20),card_bg,card_border,corner);
      EnsureRectangle(g_panel_prefix + "metric_1_accent",inner_x + ScalePx(4),card_y + ScalePx(20),ScalePx(2),m.card_metrics_h - ScalePx(56),green_dark,green_dark,corner);
      EnsureLabel(g_panel_prefix + "metric_1_t","今日进度",inner_x + ScalePx(36),card_y + ScalePx(17),m.font_sm,soft,corner);
      EnsureLabel(g_panel_prefix + "metric_1_v",FormatSignedMoney(today_progress) + " " + currency,inner_x + ScalePx(18),card_y + ScalePx(43),metric_value_font,today_progress >= 0.0 ? green : red,corner,"Microsoft YaHei UI");
      EnsureLabel(g_panel_prefix + "metric_1_s",daily_equity_text,inner_x + ScalePx(24),card_y + ScalePx(76),m.font_sm,daily_equity_loss ? red : green,corner);

      const int card2_x=inner_x + ScalePx(4) + card_w + card_gap;
      EnsureRectangle(g_panel_prefix + "metric_2",card2_x,card_y,card_w,m.card_metrics_h - ScalePx(20),card_bg,card_border,corner);
      EnsureLabel(g_panel_prefix + "metric_2_t","今日已平",card2_x + ScalePx(36),card_y + ScalePx(17),m.font_sm,soft,corner);
      EnsureLabel(g_panel_prefix + "metric_2_v",FormatSignedMoney(today_profit) + " " + currency,card2_x + ScalePx(18),card_y + ScalePx(43),metric_value_font,blue,corner,"Microsoft YaHei UI");
      EnsureLabel(g_panel_prefix + "metric_2_s","已平仓 " + IntegerToString(closed_count) + " 笔",card2_x + ScalePx(30),card_y + ScalePx(76),m.font_sm,soft,corner);

      const int card3_x=card2_x + card_w + card_gap;
      EnsureRectangle(g_panel_prefix + "metric_3",card3_x,card_y,card_w,m.card_metrics_h - ScalePx(20),card_bg,card_border,corner);
      EnsureLabel(g_panel_prefix + "metric_3_t","账户余额",card3_x + ScalePx(36),card_y + ScalePx(17),m.font_sm,soft,corner);
      EnsureLabel(g_panel_prefix + "metric_3_v",DoubleToString(balance,2) + " " + currency,card3_x + ScalePx(14),card_y + ScalePx(43),metric_balance_font,gold,corner,"Microsoft YaHei UI");
      EnsureLabel(g_panel_prefix + "metric_3_s","净值 " + DoubleToString(equity,2),card3_x + ScalePx(18),card_y + ScalePx(76),m.font_sm,soft,corner);
     }
   y+=m.card_metrics_h + m.section_gap;
   EnsureLabel(g_panel_prefix + "actions_title","快捷操作",inner_x + ScalePx(10),y + ScalePx(0),m.font_md,muted,corner);

   int strip_y=y + ScalePx(28);
   EnsureRectangle(g_panel_prefix + "display_green",inner_x + ScalePx(4),strip_y,inner_w - ScalePx(8),m.button_h,green_dark,green_dark,corner);
   EnsureLabel(g_panel_prefix + "display_green_icon","▶",inner_x + inner_w / 2 - ScalePx(72),strip_y + ScalePx(10),ScaleFont(16),white,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "display_green_text",main_button_text,inner_x + inner_w / 2 - ScalePx(38),strip_y + ScalePx(8),ScaleFont(19),white,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "display_green_sub",m.compact ? trade_line_compact : trade_line,inner_x + (m.compact ? ScalePx(18) : ScalePx(118)),strip_y + m.button_h + ScalePx(8),m.font_sm,muted,corner);

   strip_y+=m.button_h + ScalePx(48);
   EnsureRectangle(g_panel_prefix + "display_red",inner_x + ScalePx(4),strip_y,inner_w - ScalePx(8),m.button_h,red_dark,red_dark,corner);
   EnsureLabel(g_panel_prefix + "display_red_icon","■",inner_x + inner_w / 2 - ScalePx(70),strip_y + ScalePx(11),ScaleFont(15),white,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "display_red_text","平账号全部",inner_x + inner_w / 2 - ScalePx(38),strip_y + ScalePx(8),ScaleFont(19),white,corner,"Microsoft YaHei UI");
   EnsureLabel(g_panel_prefix + "display_red_sub",m.compact ? "平掉本账号所有EA订单" : "平掉本账号所有EA订单（含多单、空单）",inner_x + (m.compact ? ScalePx(18) : ScalePx(116)),strip_y + m.button_h + ScalePx(8),m.font_sm,muted,corner);

   const int foot_y=y0 + m.panel_h - ScalePx(30);
   EnsureRectangle(g_panel_prefix + "footer_line",inner_x + ScalePx(8),foot_y - ScalePx(8),inner_w - ScalePx(16),ScalePx(1),C'25,34,44',C'25,34,44',corner);
   EnsureLabel(g_panel_prefix + "brand","多米诺量化  D2",panel_right - ScalePx(132),foot_y + ScalePx(2),m.font_sm,muted,corner);

   if(exposure_count > 0)
      EnsureLabel(g_panel_prefix + "exposure_hint","持仓 " + IntegerToString(exposure_count) + " 笔",inner_x + ScalePx(14),foot_y + ScalePx(2),m.font_sm,soft,corner);
   else
      ObjectDelete(0,g_panel_prefix + "exposure_hint");
  }
void RefreshPanel(const bool force)
  {
   const datetime now_second=TimeCurrent();
   if(!force && now_second == g_last_panel_refresh)
      return;

   EAStats stats;
   CollectStats(stats);
   DrawPanel(stats);
   g_last_panel_refresh=now_second;
   ChartRedraw(0);
  }

void DeleteObjectsByPrefix(const string prefix)
  {
   for(int i=ObjectsTotal(0,-1,-1)-1; i>=0; --i)
     {
      const string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,prefix,0) == 0)
         ObjectDelete(0,name);
     }
  }
