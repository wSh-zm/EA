#property strict
#property version   "1.00"
#property description "多米诺量化M3"

#include <Trade/Trade.mqh>

enum OpenModeEnum
  {
   OpenMode_Bar      = 1,
   OpenMode_Interval = 2,
   OpenMode_NoDelay  = 3
  };
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
ENUM_TIMEFRAMES      TimeZone                               = PERIOD_M1; // 开单时区
input int            sleep                                   = 30;      // 开单时间间距(秒)
input double         MaxLoss                                 = 100000.0;// 单边浮亏超过多少不继续加仓
input double         MaxLossCloseAll                         = 50.0;    // 单边平仓限制

input group "风控参数"
input double         lot                                     = 0.01;    // 起始手数
input double         Maxlot                                  = 10.0;    // 最大开单手数
input double         PlusLot                                 = 0.0;     // 累加手数
input double         K_Lot                                   = 1.3;     // 倍率
input int            DigitsLot                               = 2;       // 下单量小数位
input double         CloseAll                                = 0.5;     // 整体平仓金额
input bool           Profit                                  = true;    // 单边平仓金额累加开关
input double         StopProfit                              = 2.0;     // 单边平仓金额
input double         StopLoss                                = 0.0;     // 止损金额
long                 Magic                                   = 958999848; // 魔术号
input int            Totals                                  = 50;      // 最大单量
int                  MaxSpread                               = 60;      // 点差限制(点)
int                  Leverage                                = 100;     // 平台杠杆限制

// 交易时段参数隐藏，不在参数页显示
bool                 EnableTradingSessionWindow             = false;    // 启用工作时间段控制
string               EA_StartTime                            = "00:00"; // EA开始时间
string               EA_StopTime                             = "24:00"; // EA结束时间
bool                 EnableDailyWrapUpPhase                 = false;    // 启用日内收尾阶段
string               DailyWrapUpStartTime                   = "20:00"; // 收尾开始(盘面/服务器时间)
string               DailyWrapUpStopTime                    = "24:00"; // 收尾结束(盘面/服务器时间)
bool                 EnableDailyProfitTarget                = false;    // 启用每日盈利目标
double               DailyProfitTarget                       = 50.0;    // 每日盈利目标，达到后封盘

// 本地授权配置：每个账号对应一个到期时间；服务器留空表示不限制服务器。
bool     LicenseEnabled=true;
long     LicensedAccounts[]={9000347,610728,601758,601757,9000347};
datetime LicensedExpires[]={D'2026.07.30 23:59:59',D'2026.06.24 23:59:59',D'2026.07.22 23:59:59',D'2026.06.24 23:59:59',D'2026.06.24 23:59:59'};
string   LicensedServers[]={"",""};
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
   int               panel_h;
   int               toggle_w;
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
string               g_panel_prefix           = "GoldKylinMT5.";

#define GOLDKING_ORDER_COMMENT_PRIMARY   "FXKiller_GoldKing"
#define GOLDKING_ORDER_COMMENT_SECONDARY "FXKiller_GoldKing_SS"

bool       IsTestingMode();
datetime   ReferenceNow();
bool       CheckLocalLicense(const bool show_alert);
string     CleanTimeString(const string value);
datetime   TodayAt(const string time_text,const datetime now_value);
bool       IsInWindow(const string start_text,const string stop_text,const datetime now_value);
bool       IsAfterSessionStop(const datetime now_value);
bool       IsTradingSessionOpen(const datetime now_value);
bool       IsTradingSessionAfterStop(const datetime now_value);
bool       IsDailyWrapUpWindow(const datetime now_value);
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

   ExecuteStrategy();
  }

void OnTimer()
  {
   if(!CheckLocalLicense(false))
      return;

   RefreshPanel(false);
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(!CheckLocalLicense(true))
      return;

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   const string key=sparam;
   if(key == g_panel_prefix + "toggle_panel")
     {
      g_panel_open = !g_panel_open;
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "stop_all")
     {
      const bool currently_on=(g_allow_buy || g_allow_sell);
      g_allow_buy = !currently_on;
      g_allow_sell = !currently_on;
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "stop_buy")
     {
      g_allow_buy = !g_allow_buy;
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "stop_sell")
     {
      g_allow_sell = !g_allow_sell;
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "close_profit")
     {
      ClosePositionsByProfitState(true);
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "close_loss")
     {
      ClosePositionsByProfitState(false);
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "close_buy")
     {
      CloseEaOrders(1,false,false);
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "close_sell")
     {
      CloseEaOrders(-1,false,false);
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "close_symbol")
     {
      CloseCurrentSymbolPositions();
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "close_ea")
     {
      CloseEaOrders(0,false,false);
      RefreshPanel(true);
      return;
     }

   if(key == g_panel_prefix + "close_account")
     {
      CloseAllAccountPositions();
      RefreshPanel(true);
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
   if(!LicenseEnabled)
      return(true);

   const long login=(long)AccountInfoInteger(ACCOUNT_LOGIN);
   const string server=AccountInfoString(ACCOUNT_SERVER);
   datetime now=TimeTradeServer();
   if(now <= 0)
      now=TimeCurrent();
   if(now <= 0)
      now=TimeLocal();

   const int account_count=ArraySize(LicensedAccounts);
   const int expire_count=ArraySize(LicensedExpires);
   const int server_count=ArraySize(LicensedServers);

   for(int i=0; i<account_count; ++i)
     {
      if(login != LicensedAccounts[i])
         continue;

      if(i < server_count && LicensedServers[i] != "" && server != LicensedServers[i])
        {
         if(show_alert)
            Alert("授权失败：服务器不匹配，当前服务器=",server);
         Print("授权失败：服务器不匹配，login=",login," server=",server);
         return(false);
        }

      if(i >= expire_count || LicensedExpires[i] <= 0)
        {
         if(show_alert)
            Alert("授权失败：未设置到期时间，账号=",login);
         Print("授权失败：未设置到期时间，login=",login);
         return(false);
        }

      if(now > LicensedExpires[i])
        {
         if(show_alert)
            Alert("授权失败：授权已到期，账号=",login," 到期=",TimeToString(LicensedExpires[i],TIME_DATE|TIME_MINUTES));
         Print("授权失败：授权已到期，login=",login," expire=",TimeToString(LicensedExpires[i],TIME_DATE|TIME_MINUTES));
         return(false);
        }

      return(true);
     }

   if(show_alert)
      Alert("授权失败：账号未授权，当前账号=",login);
   Print("授权失败：账号未授权，login=",login," server=",server);
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
   const int min_distance=BrokerMinDistancePoints();
   const int first_step=MathMax(FirstStep,min_distance);
   const int buy_min_distance=MathMax(MinDistance,min_distance);
   const int sell_min_distance=MathMax(MinDistance,min_distance);
   const int buy_two_min_distance=MathMax(TwoMinDistance,min_distance);
   const int sell_two_min_distance=MathMax(TwoMinDistance,min_distance);
   const int buy_step=MathMax(Step,min_distance);
   const int sell_step=MathMax(Step,min_distance);
   const int buy_two_step=MathMax(TwoStep,min_distance);
   const int sell_two_step=MathMax(TwoStep,min_distance);
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

   if(allow_buy && stats.buy_pending == 0 && stats.buy_profit > g_max_loss_limit)
     {
      double target_price=0.0;
      if(stats.buy_positions == 0)
         target_price=NormalizePriceToSymbol(ask_price + first_step * _Point);
      else
        {
         target_price=NormalizePriceToSymbol(ask_price + (primary_params ? buy_min_distance : buy_two_min_distance) * _Point);
         if(stats.buy_lowest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.buy_lowest_position - (primary_params ? buy_step : buy_two_step) * _Point))
            target_price=NormalizePriceToSymbol(ask_price + (primary_params ? buy_step : buy_two_step) * _Point);
        }

      const bool buy_condition=
         (stats.buy_positions == 0) ||
         (stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_step * _Point) && buy_rebalance && primary_params) ||
         (stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_two_step * _Point) && buy_rebalance && !primary_params && Money != 0.0) ||
         (stats.buy_lowest_position != 0.0 && target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - buy_step * _Point) && primary_params) ||
         (stats.buy_lowest_position != 0.0 && target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - buy_two_step * _Point) && !primary_params && Money != 0.0) ||
         (Homeopathy && stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_step * _Point) && lots_equal);

      if(buy_condition && AllowBuyOrderByPriceLimit(stats,target_price,limit_window_active) && CanOpenThisCycle(true,stats))
        {
         double volume=(stats.buy_positions == 0) ? lot : (stats.buy_positions * PlusLot + lot * MathPow(K_Lot,stats.buy_positions));
         volume=NormalizeVolumeToSymbol(volume);
         const bool use_secondary_comment=
            ((stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_step * _Point) && buy_rebalance && primary_params) ||
             (stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_two_step * _Point) && buy_rebalance && !primary_params && Money != 0.0) ||
             (Homeopathy && stats.buy_highest_any != 0.0 && target_price >= NormalizePriceToSymbol(stats.buy_highest_any + buy_step * _Point) && lots_equal));

         CheckTradeResult(g_trade.BuyStop(volume,target_price,_Symbol,0.0,0.0,ORDER_TIME_GTC,0,use_secondary_comment ? GOLDKING_ORDER_COMMENT_SECONDARY : GOLDKING_ORDER_COMMENT_PRIMARY),"BuyStop");
        }
     }

   if(allow_sell && stats.sell_pending == 0 && stats.sell_profit > g_max_loss_limit)
     {
      double target_price=0.0;
      if(stats.sell_positions == 0)
         target_price=NormalizePriceToSymbol(bid_price - first_step * _Point);
      else
        {
         target_price=NormalizePriceToSymbol(bid_price - (primary_params ? sell_min_distance : sell_two_min_distance) * _Point);
         if(stats.sell_highest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.sell_highest_position + (primary_params ? sell_step : sell_two_step) * _Point))
            target_price=NormalizePriceToSymbol(bid_price - (primary_params ? sell_step : sell_two_step) * _Point);
        }

      const bool sell_condition=
         (stats.sell_positions == 0) ||
         (stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_step * _Point) && sell_rebalance && primary_params) ||
         (stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_two_step * _Point) && sell_rebalance && !primary_params && Money != 0.0) ||
         (stats.sell_highest_position != 0.0 && target_price >= NormalizePriceToSymbol(stats.sell_highest_position + sell_step * _Point) && primary_params) ||
         (stats.sell_highest_position != 0.0 && target_price >= NormalizePriceToSymbol(stats.sell_highest_position + sell_two_step * _Point) && !primary_params && Money != 0.0) ||
         (Homeopathy && stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_step * _Point) && lots_equal);

      if(sell_condition && AllowSellOrderByPriceLimit(stats,target_price,limit_window_active) && CanOpenThisCycle(false,stats))
        {
         double volume=(stats.sell_positions == 0) ? lot : (stats.sell_positions * PlusLot + lot * MathPow(K_Lot,stats.sell_positions));
         volume=NormalizeVolumeToSymbol(volume);
         const bool use_secondary_comment=
            ((stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_step * _Point) && sell_rebalance && primary_params) ||
             (stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_two_step * _Point) && sell_rebalance && !primary_params && Money != 0.0) ||
             (Homeopathy && stats.sell_lowest_any != 0.0 && target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - sell_step * _Point) && lots_equal));

         CheckTradeResult(g_trade.SellStop(volume,target_price,_Symbol,0.0,0.0,ORDER_TIME_GTC,0,use_secondary_comment ? GOLDKING_ORDER_COMMENT_SECONDARY : GOLDKING_ORDER_COMMENT_PRIMARY),"SellStop");
        }
     }

   if(OpenMode == OpenMode_Bar && current_bar != 0)
      g_last_open_bar_time=current_bar;
  }

void TryTrailPendingOrders(const EAStats &stats,const bool allow_buy,const bool allow_sell)
  {
   const int min_distance=BrokerMinDistancePoints();
   const int first_step=MathMax(FirstStep,min_distance);
   const int primary_min=MathMax(MinDistance,min_distance);
   const int second_min=MathMax(TwoMinDistance,min_distance);
   const int primary_step=MathMax(Step,min_distance);
   const int second_step=MathMax(TwoStep,min_distance);
   const bool primary_params=ShouldUsePrimaryParameters(stats);
   const bool buy_rebalance=(stats.buy_lots > 0.0 && stats.sell_lots / stats.buy_lots > 3.0 && stats.sell_lots - stats.buy_lots > 0.2);
   const bool sell_rebalance=(stats.sell_lots > 0.0 && stats.buy_lots / stats.sell_lots > 3.0 && stats.buy_lots - stats.sell_lots > 0.2);
   const double ask_price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double bid_price=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(allow_buy && stats.buy_pending_ticket > 0)
     {
      double target_price=(stats.buy_positions == 0) ? NormalizePriceToSymbol(ask_price + first_step * _Point)
                                                     : NormalizePriceToSymbol(ask_price + (primary_params ? primary_min : second_min) * _Point);
      if(stats.buy_positions > 0 && stats.buy_lowest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.buy_lowest_position - (primary_params ? primary_step : second_step) * _Point))
         target_price=NormalizePriceToSymbol(ask_price + (primary_params ? primary_step : second_step) * _Point);

      const bool trail_ok=
         primary_params ?
         (target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - primary_step * _Point) || stats.buy_lowest_position == 0.0 || (buy_rebalance && stats.buy_positions == 0) || target_price >= NormalizePriceToSymbol(stats.buy_highest_any + primary_step * _Point))
         :
         (target_price <= NormalizePriceToSymbol(stats.buy_lowest_position - second_step * _Point) || stats.buy_lowest_position == 0.0 || (buy_rebalance && stats.buy_positions == 0) || target_price >= NormalizePriceToSymbol(stats.buy_highest_any + second_step * _Point));

      if(stats.buy_pending_price != 0.0 && NormalizePriceToSymbol(stats.buy_pending_price - StepTrallOrders * _Point) > target_price && trail_ok)
         ModifyPendingPrice(stats.buy_pending_ticket,target_price);
     }

   if(allow_sell && stats.sell_pending_ticket > 0)
     {
      double target_price=(stats.sell_positions == 0) ? NormalizePriceToSymbol(bid_price - first_step * _Point)
                                                      : NormalizePriceToSymbol(bid_price - (primary_params ? primary_min : second_min) * _Point);
      if(stats.sell_positions > 0 && stats.sell_highest_position != 0.0 && target_price < NormalizePriceToSymbol(stats.sell_highest_position + (primary_params ? primary_step : second_step) * _Point))
         target_price=NormalizePriceToSymbol(bid_price - (primary_params ? primary_step : second_step) * _Point);

      const bool trail_ok=
         primary_params ?
         (target_price >= NormalizePriceToSymbol(stats.sell_highest_position + primary_step * _Point) || stats.sell_highest_position == 0.0 || (sell_rebalance && stats.sell_positions == 0) || target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - primary_step * _Point))
         :
         (target_price >= NormalizePriceToSymbol(stats.sell_highest_position + second_step * _Point) || stats.sell_highest_position == 0.0 || (sell_rebalance && stats.sell_positions == 0) || target_price <= NormalizePriceToSymbol(stats.sell_lowest_any - second_step * _Point));

      if(stats.sell_pending_price != 0.0 && NormalizePriceToSymbol(stats.sell_pending_price + StepTrallOrders * _Point) < target_price && trail_ok)
         ModifyPendingPrice(stats.sell_pending_ticket,target_price);
     }
  }

void ExecuteStrategy()
  {
   EAStats stats;
   CollectStats(stats);
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
      scale=1.08;
   else if(dpi >= 160)
      scale=1.04;
   else if(dpi <= 96)
      scale=0.98;

   if(chart_width <= 1280)
      scale=MathMin(scale,0.94);
   else if(chart_width >= 2400)
      scale=MathMin(MathMax(scale,1.0),1.08);

   return(MathMax(0.90,MathMin(scale,1.10)));
  }

double UiFontScale()
  {
   const long chart_width=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   const long dpi=TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   double scale=1.0;

   if(dpi >= 192)
      scale=1.05;
   else if(dpi >= 160)
      scale=1.02;
   else if(dpi <= 96)
      scale=0.97;

   if(chart_width <= 1280)
      scale=MathMin(scale,0.96);

   return(MathMax(0.92,MathMin(scale,1.06)));
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
   const int available_w=(int)MathMax(300.0,(double)chart_width - ScalePx(36));

   m.margin_x       = ScalePx(16);
   m.margin_y       = ScalePx(18);
   m.width          = (int)MathMax(300.0,MathMin((double)ScalePx(440),(double)available_w));
   m.pad            = ScalePx(14);
   m.section_gap    = ScalePx(10);
   m.header_h       = ScalePx(56);
   m.row_h          = ScalePx(18);
   m.gap            = ScalePx(8);
   m.button_h       = ScalePx(30);
   m.inner_w        = m.width - m.pad * 2;
   m.half_w         = (m.inner_w - m.gap) / 2;
   m.card_status_h  = g_panel_open ? ScalePx(184) : ScalePx(172);
   m.card_metrics_h = g_panel_open ? ScalePx(236) : ScalePx(164);
   m.card_actions_h = g_panel_open ? (m.pad * 2 + ScalePx(22) + m.gap + m.button_h * 6 + m.gap * 5) : (m.pad * 2 + ScalePx(22) + m.gap + m.button_h);
   m.button_font    = ScaleFont(9);
   m.font_xs        = ScaleFont(9);
   m.font_sm        = ScaleFont(10);
   m.font_md        = ScaleFont(11);
   m.font_lg        = ScaleFont(15);
   m.toggle_w       = (m.width <= ScalePx(340)) ? ScalePx(56) : ScalePx(64);
   m.panel_h        = m.header_h + m.section_gap + m.card_status_h + m.section_gap + m.card_metrics_h + m.section_gap + m.card_actions_h;
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
   const color panel_bg=C'15,20,27';
   const color panel_border=C'45,58,74';
   const color header_bg=C'20,29,40';
   const color card_bg=C'24,33,45';
   const color muted=C'150,164,181';
   const color ok_color=C'88,199,135';
   const color warn_color=C'255,183,77';
   const color bad_color=C'239,100,97';
   const color accent=C'66,153,225';
   const color accent_alt=C'34,197,154';
   const color cream=C'244,248,252';

   const int x=m.margin_x;
   const int inner_x=x + m.pad;
   const int inner_x2=inner_x + m.half_w + m.gap;
   const int right_button_x=x + m.width - m.pad - m.toggle_w;
   const int reason_chars=(int)MathMax(24.0,MathMin(42.0,(double)m.width / 10.0 - 2.0));
   const int info_chars=(int)MathMax(26.0,MathMin(48.0,(double)m.width / 8.0));
   const datetime now_value=ReferenceNow();
   RefreshDailyLocks(now_value,stats);

   const double spread_pips=CurrentSpreadPoints() / PipDivisor();
   const double today_profit=TodayClosedProfit(now_value);
   const double today_progress=TodayProgressProfit(now_value,stats);
   const double yesterday_profit=CalculateClosedProfit(TodayAt("00:00",now_value) - 86400,TodayAt("00:00",now_value) - 1,Magic,true);
   const double total_closed=CalculateClosedProfit(0,TimeCurrent(),Magic,true);
   const double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const double margin=AccountInfoDouble(ACCOUNT_MARGIN);
   const double margin_level=(margin > 0.0) ? equity / margin * 100.0 : 0.0;
   const bool target_enabled=(EnableDailyProfitTarget && DailyProfitTarget > 0.0);
   const double target_progress_display=g_daily_target_locked ? MathMax(today_progress,g_daily_target_hit_value) : today_progress;
   const double target_remaining=target_enabled ? MathMax(0.0,DailyProfitTarget - target_progress_display) : 0.0;
   const bool session_open=IsTradingSessionOpen(now_value);
   const bool session_after_stop=IsTradingSessionAfterStop(now_value);
   const bool waiting_start=(!session_open && !session_after_stop);
   const bool wrap_up_active=IsDailyWrapUpWindow(now_value);
   const bool wrap_up_waiting_close=wrap_up_active && HasOpenPositions(stats);
   const bool waiting_close=(session_after_stop && HasOpenPositions(stats)) || (g_daily_target_locked && HasOpenPositions(stats)) || wrap_up_waiting_close;
   const string stop_reason=CloseReasonText();
   const string stop_reason_display=(stop_reason == "" ? "环境正常，可开新单" : stop_reason);
   const string entry_state=EntryStateText(stop_reason);
   const string session_state=SessionStateText(now_value,stats);
   const string wrap_state=WrapUpStateText(stats);
   const string goal_state=GoalStateText(target_progress_display);
   string work_state="工作中";
   color  work_color=ok_color;
   if(g_daily_target_locked)
     {
      work_state=waiting_close ? "盈利达标，待平仓" : "今日盈利达标";
      work_color=accent_alt;
     }
   else if(wrap_up_active)
     {
      work_state=wrap_up_waiting_close ? "日内收尾，待平仓" : "日内收尾";
      work_color=warn_color;
     }
   else if(waiting_close)
     {
      work_state="已到结束时间，待平仓";
      work_color=warn_color;
     }
   else if(session_after_stop)
     {
      work_state="今日已收工";
      work_color=accent;
     }
   else if(waiting_start)
     {
      work_state="等待工作时段";
      work_color=muted;
     }
   else if(!g_allow_buy && !g_allow_sell)
     {
      work_state="手动暂停";
      work_color=bad_color;
     }
   else if(stop_reason != "")
     {
      work_state="暂停中";
      work_color=warn_color;
     }
   else if(!g_allow_buy || !g_allow_sell)
     {
      work_state="单边运行";
      work_color=accent_alt;
     }
   const string subtitle=ClipText(_Symbol + "  |  " + TimeframeLabel((ENUM_TIMEFRAMES)TimeZone) + "  |  " + AccountInfoString(ACCOUNT_CURRENCY),
                                  (int)MathMax(20.0,MathMin(34.0,(double)m.width / 12.0)));

   EnsureRectangle(g_panel_prefix + "panel",x,m.margin_y,m.width,m.panel_h,panel_bg,panel_border,corner);
   EnsureRectangle(g_panel_prefix + "header",x,m.margin_y,m.width,m.header_h,header_bg,panel_border,corner);
   EnsureRectangle(g_panel_prefix + "header_accent",x,m.margin_y,ScalePx(5),m.header_h,accent,accent,corner);
   EnsureLabel(g_panel_prefix + "title","M3",inner_x + ScalePx(6),m.margin_y + ScalePx(10),m.font_lg,cream,corner);
   EnsureLabel(g_panel_prefix + "subtitle",subtitle,inner_x + ScalePx(6),m.margin_y + ScalePx(31),m.font_sm,muted,corner);
   EnsureButton(g_panel_prefix + "toggle_panel",g_panel_open ? "收起" : "展开",right_button_x,m.margin_y + ScalePx(13),m.toggle_w,m.button_h,accent,White,corner);

   int y=m.margin_y + m.header_h + m.section_gap;
   EnsureRectangle(g_panel_prefix + "card_status",x,y,m.width,m.card_status_h,card_bg,panel_border,corner);
   EnsureLabel(g_panel_prefix + "status_title","工作状态",inner_x,y + m.pad - ScalePx(1),m.font_md,cream,corner);
   EnsureLabel(g_panel_prefix + "status_line1","当前  " + work_state,inner_x,y + m.pad + ScalePx(20),m.font_sm,work_color,corner);
   EnsureLabel(g_panel_prefix + "status_line2",ClipText("交易  " + entry_state + "  |  多空  " + BoolText(g_allow_buy,"多开","多停") + "/" + BoolText(g_allow_sell,"空开","空停"),info_chars),inner_x,y + m.pad + ScalePx(40),m.font_sm,cream,corner);
   EnsureLabel(g_panel_prefix + "status_line3",ClipText("时段  " + (EnableTradingSessionWindow ? EA_StartTime + "-" + EA_StopTime : "--") + "  |  " + session_state,info_chars),inner_x,y + m.pad + ScalePx(60),m.font_sm,muted,corner);
   EnsureLabel(g_panel_prefix + "status_line4",ClipText("收尾  " + wrap_state,info_chars),inner_x,y + m.pad + ScalePx(80),m.font_xs,wrap_up_active ? warn_color : muted,corner);
   EnsureLabel(g_panel_prefix + "status_line5",ClipText("目标  " + goal_state,info_chars),inner_x,y + m.pad + ScalePx(120),m.font_xs,g_daily_target_locked ? accent_alt : cream,corner);
   EnsureLabel(g_panel_prefix + "status_line6","原因  " + ClipText(stop_reason_display,reason_chars),inner_x,y + m.pad + ScalePx(140),m.font_xs,stop_reason == "" ? muted : warn_color,corner);

   y+=m.card_status_h + m.section_gap;
   EnsureRectangle(g_panel_prefix + "card_metrics",x,y,m.width,m.card_metrics_h,card_bg,panel_border,corner);
   EnsureLabel(g_panel_prefix + "metrics_title","今日目标与账户",inner_x,y + m.pad - ScalePx(1),m.font_md,cream,corner);

   int line_y=y + m.pad + ScalePx(22);
   EnsureLabel(g_panel_prefix + "metrics_a_l","今日已平  " + FormatSignedMoney(today_profit),inner_x,line_y,m.font_sm,today_profit >= 0.0 ? ok_color : bad_color,corner);
   EnsureLabel(g_panel_prefix + "metrics_a_r",
               !EnableDailyProfitTarget ? "目标  已关闭" :
               (target_enabled ? ("目标  +" + DoubleToString(DailyProfitTarget,2)) : "目标  金额<=0"),
               inner_x2,
               line_y,
               m.font_sm,
               target_enabled ? accent : muted,
               corner);

   line_y+=m.row_h + m.gap / 2;
   EnsureLabel(g_panel_prefix + "metrics_b","今日进度  " + FormatSignedMoney(target_progress_display),inner_x,line_y,m.font_sm,target_progress_display >= 0.0 ? ok_color : bad_color,corner);
   line_y+=m.row_h + m.gap / 2;
   EnsureLabel(g_panel_prefix + "metrics_c",
               !EnableDailyProfitTarget ? "今日目标  已关闭" :
               (target_enabled ? (g_daily_target_locked ? "今日目标  已达成并封盘" : "目标剩余  " + DoubleToString(target_remaining,2)) : "今日目标  金额<=0"),
               inner_x,
               line_y,
               m.font_sm,
               g_daily_target_locked ? accent_alt : muted,
               corner);
   line_y+=m.row_h + m.gap / 2;
   EnsureLabel(g_panel_prefix + "metrics_d_l","Buy  " + IntegerToString(stats.buy_positions) + "单  " + DoubleToString(stats.buy_lots,2) + "手",inner_x,line_y,m.font_sm,cream,corner);
   EnsureLabel(g_panel_prefix + "metrics_d_r","Sell  " + IntegerToString(stats.sell_positions) + "单  " + DoubleToString(stats.sell_lots,2) + "手",inner_x2,line_y,m.font_sm,cream,corner);
   line_y+=m.row_h + m.gap / 2;
   EnsureLabel(g_panel_prefix + "metrics_e_l","Buy浮盈  " + FormatSignedMoney(stats.buy_profit),inner_x,line_y,m.font_sm,stats.buy_profit >= 0.0 ? ok_color : bad_color,corner);
   EnsureLabel(g_panel_prefix + "metrics_e_r","Sell浮盈  " + FormatSignedMoney(stats.sell_profit),inner_x2,line_y,m.font_sm,stats.sell_profit >= 0.0 ? ok_color : bad_color,corner);
   line_y+=m.row_h + m.gap / 2;
   EnsureLabel(g_panel_prefix + "metrics_f_l","EA浮盈亏  " + FormatSignedMoney(stats.total_profit),inner_x,line_y,m.font_sm,stats.total_profit >= 0.0 ? ok_color : bad_color,corner);
   EnsureLabel(g_panel_prefix + "metrics_f_r","昨日已平  " + FormatSignedMoney(yesterday_profit),inner_x2,line_y,m.font_sm,yesterday_profit >= 0.0 ? ok_color : bad_color,corner);

   if(g_panel_open)
     {
      line_y+=m.row_h + m.gap / 2;
      EnsureLabel(g_panel_prefix + "metrics_g_l","累计已平  " + FormatSignedMoney(total_closed),inner_x,line_y,m.font_sm,total_closed >= 0.0 ? ok_color : bad_color,corner);
      EnsureLabel(g_panel_prefix + "metrics_g_r","保证金比  " + FormatPercent(margin_level),inner_x2,line_y,m.font_sm,margin_level >= 200.0 ? ok_color : warn_color,corner);

      line_y+=m.row_h + m.gap / 2;
      EnsureLabel(g_panel_prefix + "metrics_h_l","余额  " + FormatSignedMoney(balance),inner_x,line_y,m.font_sm,cream,corner);
      EnsureLabel(g_panel_prefix + "metrics_h_r","净值  " + FormatSignedMoney(equity),inner_x2,line_y,m.font_sm,accent_alt,corner);

      line_y+=m.row_h + m.gap / 2;
      EnsureLabel(g_panel_prefix + "metrics_i_l","点差  " + DoubleToString(spread_pips,1) + " pips",inner_x,line_y,m.font_sm,muted,corner);
      EnsureLabel(g_panel_prefix + "metrics_i_r","杠杆  " + IntegerToString((int)AccountInfoInteger(ACCOUNT_LEVERAGE)) + "x",inner_x2,line_y,m.font_sm,muted,corner);
     }
   else
     {
      line_y+=m.row_h + m.gap / 2;
      EnsureLabel(g_panel_prefix + "metrics_g_l","余额  " + FormatSignedMoney(balance),inner_x,line_y,m.font_sm,cream,corner);
      EnsureLabel(g_panel_prefix + "metrics_g_r","净值  " + FormatSignedMoney(equity),inner_x2,line_y,m.font_sm,accent_alt,corner);
      ObjectDelete(0,g_panel_prefix + "metrics_h_l");
      ObjectDelete(0,g_panel_prefix + "metrics_h_r");
      ObjectDelete(0,g_panel_prefix + "metrics_i_l");
      ObjectDelete(0,g_panel_prefix + "metrics_i_r");
     }

   y+=m.card_metrics_h + m.section_gap;
   EnsureRectangle(g_panel_prefix + "card_actions",x,y,m.width,m.card_actions_h,card_bg,panel_border,corner);
   EnsureLabel(g_panel_prefix + "actions_title","快捷操作",inner_x,y + m.pad - ScalePx(1),m.font_md,cream,corner);

   int button_y=y + m.pad + ScalePx(24);
   EnsureButton(g_panel_prefix + "stop_all",BoolText(!(g_allow_buy || g_allow_sell),"开启交易","停止交易"),inner_x,button_y,m.inner_w,m.button_h,(g_allow_buy || g_allow_sell) ? bad_color : accent_alt,White,corner);

   if(g_panel_open)
     {
      button_y+=m.button_h + m.gap;
      EnsureButton(g_panel_prefix + "stop_buy",BoolText(g_allow_buy,"停止做多","开启做多"),inner_x,button_y,m.half_w,m.button_h,g_allow_buy ? warn_color : accent_alt,White,corner);
      EnsureButton(g_panel_prefix + "stop_sell",BoolText(g_allow_sell,"停止做空","开启做空"),inner_x2,button_y,m.half_w,m.button_h,g_allow_sell ? warn_color : accent_alt,White,corner);

      button_y+=m.button_h + m.gap;
      EnsureButton(g_panel_prefix + "close_symbol","平当前品种",inner_x,button_y,m.half_w,m.button_h,accent,White,corner);
      EnsureButton(g_panel_prefix + "close_profit","平盈利单",inner_x2,button_y,m.half_w,m.button_h,accent_alt,White,corner);

      button_y+=m.button_h + m.gap;
      EnsureButton(g_panel_prefix + "close_loss","平亏损单",inner_x,button_y,m.half_w,m.button_h,bad_color,White,corner);
      EnsureButton(g_panel_prefix + "close_buy","平多单",inner_x2,button_y,m.half_w,m.button_h,C'29,78,216',White,corner);

      button_y+=m.button_h + m.gap;
      EnsureButton(g_panel_prefix + "close_sell","平空单",inner_x,button_y,m.half_w,m.button_h,C'185,74,72',White,corner);
      EnsureButton(g_panel_prefix + "close_ea","平本EA全部",inner_x2,button_y,m.half_w,m.button_h,C'121,89,214',White,corner);

      button_y+=m.button_h + m.gap;
      EnsureButton(g_panel_prefix + "close_account","平账号全部",inner_x,button_y,m.inner_w,m.button_h,C'92,141,146',White,corner);
     }
   else
     {
      ObjectDelete(0,g_panel_prefix + "stop_buy");
      ObjectDelete(0,g_panel_prefix + "stop_sell");
      ObjectDelete(0,g_panel_prefix + "close_symbol");
      ObjectDelete(0,g_panel_prefix + "close_profit");
      ObjectDelete(0,g_panel_prefix + "close_loss");
      ObjectDelete(0,g_panel_prefix + "close_buy");
      ObjectDelete(0,g_panel_prefix + "close_sell");
      ObjectDelete(0,g_panel_prefix + "close_ea");
      ObjectDelete(0,g_panel_prefix + "close_account");
     }
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
