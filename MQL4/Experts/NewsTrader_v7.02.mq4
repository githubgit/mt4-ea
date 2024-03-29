//+------------------------------------------------------------------+
//|                                            NewsTrader_v7.02.mq4  |
//|                                              Copyright © 2018    |
//|                                 E-mail: vova.pochernin@gmail.com |
//+------------------------------------------------------------------+

//TODO
//1) Improve slippage analisys for open price, TP, SL:
//   - no writing to file or print in log during trading news event. Persist to text file after all open trades had been closed
//2) TP SL during huge move/spread resulted in huge open slippage - investigate last case & improve if possible

#property copyright "Copyright © 2018, NewsTrader_v7.02.mq4"

#property strict
#include <stdlib.mqh>

//---- input parameters
input string     ExpertName           = "NewsTrader_v7.02";

input int        Magic                =   7777777;       //Magic Number 
input int        Slippage             =         1;       //Slippage

input string     calInputs            = "===== Calendar settings =====";
input string     CalendarDirectory    = "FX News";       //Calendar Directory
input string     CalendarName         = "Investing.com"; //Calendar Name
input string     TestCalName          = "2015-2018";     //Tester Calendar Name
input string     WebAdress            = "https://ec.forexprostools.com/"; //URL to read Calendar from
input bool       UseAutoTimeZone      =      true;       //Auto TimeZone Detection
input int        TimeZone             =         2;       //Manual TimeZone
input bool       ReadFromFile         =     false;       //Read Calendar From File
input bool       PrintInLog           =      true;       //Print in Log (false-off, true-on)
input bool       DisplayLines         =      true;       //Display Lines Option (false-off, true-on)
input bool       DisplayText          =      true;       //Display Text Option (false-off, true-on)
input bool       DisplayEvents        =      true;       //Display Events Option (false-off, true-on)
input ENUM_LINE_STYLE LineStyle       = STYLE_DOT;       //Line Style

input string     timeInputs           = "===== Timing settings ====="; 
input double     SecBeforeNews        =        20;       //Seconds before News Time and Order Open Time, sec 
input int        OrderDuration        =       140;       //Pending Order Expiration, sec
input double     ProcessTime          =        10;       //Order Adjusting Time in sec
input string     SessionEndTime       =   "23:20";      //Session End Time

input string     ordInputs            = "===== Order settings =====";
input int        OrdersNum            =        23;       //Number of pending orders from one side
input int        CandlesToCheck       =         1;       //Candles to check Hi Lo
input double     PendOrdGap           =        30;       //Gap for Pending Orders from last HiLo
input double     OrdersStep           =        30;       //Step between orders
input bool       DeleteOpposite       =      true;       //Opposite Orders delete
input bool       TrailOpposite        =      true;       //Opposite Orders trailing
input bool       CloseOnNewEvent      =      true;       //Close Orders On New Event

input double     InitialStop          =        20;       //Initial Stop
input double     TakeProfit           =       150;       //Take Profit      	

input double     TrailingStop         =         0;       //Trailing Stop
input double     TrailingStep         =         0;       //Trailing Stop Step

input double     BreakEven            =        90;       //Breakeven
input double     PipsLock             =        60;       //Lock

input string     TrailTP              = "======= Dynamic TP ========";
input double     DeltaTP              =        10;       //Distance before TP to trail SL/TP
input double     MoveSL             =          40;       //Distance to move SL from current price when price closer to TP than DeltaTP

input bool       ECN_Mode             =     false;       //ECN Mode
input bool       DisplayLevels        =      true;       //Display Levels for ECN Mode
input bool       ShowComments         =      true;       //Show Comments: false-off,true-on(use only for Live Trading and Visual Testing)
input bool       ShowCalendar         =      true;       //Show Calendar  
input bool       SaveHTMFormat        =     false;       //Save HTM Format

input string     currencyFilter        = "===== Currency Filter(None-off, color-on) =====";

input bool       OnlySymbolNews       =       true;      //Use Chart Symbols Only
input color      EUR                  =    clrPink;      //Euro Zone(EUR) 
input color      USD                  =  clrDodgerBlue;  //US(USD)
input color      JPY                  =  clrOrange;      //Japan(JPY)
input color      GBP                  =     clrRed;      //UK(GBP) 
input color      CHF                  =  clrMagenta;     //Switzerland(CHF) 
input color      AUD                  =   clrGreen;      //Australia(AUD)
input color      CAD                  =  clrTomato;      //Canada(CAD) 
input color      NZD                  =    clrGray;      //New Zealand(NZD)   
input color      CNY                  =  clrOrange;      //China(CNY) 

input string     impFilter            = "===== Importance Filter =====";
input string     NewsImportance       =         "H";//"L,M,H" News Importance Filter (empty - all)

input string     chartNewsOnlyColors  = "=== Importance Color OnlySymbolNews=true  =====";
extern color     LowColor             = clrGreen;
extern color     MidleColor           = clrBlue;
extern color     HighColor            = clrRed;

input string     mmInputs             = "===== Money Management settings =====";
input int        MM_Mode              =          2;      //0-fixed lot,1-by free Margin,2-by max loss
input double     Lots                 =          0;      //Lot size
input double     RiskFactor           =        0.3;      //Risk Factor(in decimals) for MM formula 
input double     MaxLots              =        100;      //Max Lot Size
input bool       NotifyByEmail        =       true;
input bool       DetailedStatsEmail   =       true;

#define DAY_SECONDS 86400
#define RetryTime 100

int maxSlipPoints = 1; // if order open price slipped more than maxSlipPoints TP and SL will be corrected
int tstFakeSlipPoints = 0;// open price slip point during testing

string   sDate[];          // Date
string   sTime[];          // Time
string   sCurrency[];      // Currency
string   sEvent[];         // Event
string   sImportance[];    // Importance
string   sActChange[];     // Actual change
string   sActual[];        // Actual value
string   sForecast[];      // Forecast value
string   sPrevChange[];    // Previous change
string   sPrevious[];      // Previous value

string   event[];
datetime dt[]; 
string   sImpact[];
int      country[];   

double   BuyLevel[], SellLevel[]; 
int      BuyNum[], SellNum[];
int      NewsNum, TriesNum = 3, BuyEvent, SellEvent;
bool     firstTime, NewEvent;
datetime currentWeekTime, prevEventTime, nTime, OpenTime, tabTime, revtime, savedtime;
int      tz, counter, ECN_Buy, ECN_Sell;
double   dRatio, contract, lot_min, lot_step, lot_max, tick_val, _point, minstop, pAsk, pBid;
double   lotAmount;
string   StartYear, StartMonth, uniqueName = "dfx";
double   buyOrders[][2];//order ticket; requested price; 
double   sellOrders[][2];//order ticket; requested price;

//avoid unnecessary iterations of old news events
int currentNews_i=0;
string currEventInfo="";

//+------------------------------------------------------------------+
//|   Open price improvement assessment variables                    |
//+------------------------------------------------------------------+
int maxOpenPriceImprovmentTicket = 0;
int minOpenPriceImprovmentTicket = 0;
double maxOpenPriceImprovement = -1000;
double minOpenPriceImprovement = 1000;
double avgOpenPriceImprovement = 0;
double openPriceImprovedPerc = 0;
double priceBetterCounter = 0;
int priceImpCounter = 0;
double priceImpSum = 0;

//+------------------------------------------------------------------+
//|   Take Profit price improvement assessment variables             |
//+------------------------------------------------------------------+
int maxTPImprovmentTicket = 0;
int minTPImprovmentTicket = 0;
double maxTPImprovement = -1000;
double minTPImprovement = 1000;
double avgTPImprovement = 0;
double tpImprovedPerc = 0;
int tpBetterCounter = 0;
int tpCounter = 0;
double tpSum = 0;
//+------------------------------------------------------------------+
//|   Stop Loss price improvement assessment variables               |
//+------------------------------------------------------------------+
int maxSLImprovmentTicket = 0;
int minSLImprovmentTicket = 0;
double maxSLImprovement = -1000;
double minSLImprovement = 1000;
double avgSLImprovement = 0;
double slImprovedPerc = 0;
int slBetterCounter = 0;
int slCounter = 0;
double slSum = 0;
//+------------------------------------------------------------------+
//|             account statistics                                   |
//+------------------------------------------------------------------+
double minMarginLevel = DBL_MAX;
double changeAfterLastEvent = 0;
double equityBeforeEvent = 0;
double depositTotal = 0;
double changePL = 0;
//+------------------------------------------------------------------+
//|             Spread statistics                                   |
//+------------------------------------------------------------------+
double minSpread = DBL_MAX;
double maxSpread = DBL_MIN;
double avgSpread = 0;
double spreadSum = 0;
long spreadCnt = 0;

//+------------------------------------------------------------------+
//|            Last Event Spread statistics                                   |
//+------------------------------------------------------------------+
double minSpreadLE = DBL_MAX;
double maxSpreadLE = DBL_MIN;
double avgSpreadLE = 0;
double spreadSumLE = 0;
long spreadCntLE = 0;

long pndOrdersSent = false;
long shouldSendEmail = false;
string emailDetailedStats = "";

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{  counter=0;

   if(UseAutoTimeZone) Comment("Please wait! Auto TimeZone detection ",1 - counter," ticks left");

//---- 
   dRatio = 1; //5 digits//MathPow(10,Digits%2);
   _point = MarketInfo(Symbol(),MODE_POINT)*dRatio;
   
   ArrayResize(BuyLevel ,OrdersNum);
   ArrayResize(SellLevel,OrdersNum);
   ArrayResize(BuyNum   ,OrdersNum);
   ArrayResize(SellNum  ,OrdersNum);
   ArrayResize(buyOrders,OrdersNum);
   ArrayResize(sellOrders,OrdersNum);
   
   prevEventTime = TimeCurrent(); 
   firstTime  = true;
   Print("Account #",AccountNumber(), " leverage is ", AccountLeverage());
   
   double deposited = 0;
         
   if(!IsTesting()){
      readProperties();
      
      for(int i = OrdersHistoryTotal() -1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         {
         if (OrderType() == 6)
            {
               deposited += OrderProfit(); 
               //Print("The Deposit Was ", OrderProfit(), " ", AccountCurrency());
            }
         }
      }
   }
   
   depositTotal = deposited > 0 ? deposited : AccountEquity();
   
   if(depositTotal>0)
      changePL = (AccountEquity() - depositTotal)/depositTotal*100;
   
//----
   return(0);
}
  
//---- Money Management
double MoneyManagement(int mode)
{
   double maxloss = 0;
   if(MM_Mode == 2 && InitialStop > 0) maxloss = InitialStop*tick_val;
   double Lotsi = 0, maxlots = MaxLots;
   
   lot_step = MarketInfo(Symbol(),MODE_LOTSTEP);
   lot_max  = MarketInfo(Symbol(),MODE_MAXLOT);
   lot_min  = MarketInfo(Symbol(),MODE_MINLOT);
   contract = MarketInfo(Symbol(),MODE_LOTSIZE);
   
   if(mode == 1 && RiskFactor > 0)
      Lotsi = NormalizeDouble(AccountFreeMargin()*0.01*RiskFactor*AccountLeverage()/contract,2);  
   else if(mode == 2 && RiskFactor > 0 && maxloss > 0){
      Lotsi = NormalizeDouble(AccountFreeMargin()*10*RiskFactor/maxloss*AccountLeverage()/contract,2);
   }
   else
      Lotsi = Lots;
   
   Lotsi = NormalizeDouble(Lotsi/lot_step,0)*lot_step;
   
   
   if(StringFind(Symbol(),"USD",0)>-1){
      Lotsi = requiredMarginLotCorrection(Lotsi);
   }
   
   if(maxlots == 0 || maxlots>lot_max ) maxlots = lot_max;
   if(maxlots > 0 && Lotsi > maxlots) Lotsi = maxlots;
   if(Lotsi < lot_min) Lotsi = lot_min;
   
   return(Lotsi);
}

//lot correction based on required margin
double requiredMarginLotCorrection(double lot){
   //if (PrintInLog==true) Print("Lot correction...");
   
   if(requiredMargin(lot) > AccountFreeMargin() ){
      /*
      if (PrintInLog==true){ 
         Print("Required margin more that free margin");
         Print("Initial lot: ", lot);
      }
      */
      
      while(requiredMargin(lot) > AccountFreeMargin()){
        lot -= lot_step;
      }
   }else {
     //if (PrintInLog==true) Print("Required margin is OK for lot=", lot);
   }
   
   //if (PrintInLog==true) Print("Corrected lot=", lot);
   
   return lot;
}

//Simple method for USD as a base currency pairs or pairs containing account currency
double requiredMargin(double lot){
   double requiredMargin;
   if ((StringCompare(StringSubstr(Symbol(),0,3),"USD")==0))
     requiredMargin = (lot * contract)/ AccountLeverage();
   else if(StringCompare(StringSubstr(Symbol(),3,3),"USD")==0)
     // multiply with Ask - to get result in base currency we must multiply to conversion rate
     requiredMargin = (lot * contract)/ AccountLeverage() * Ask;
  
   //if (PrintInLog==true) Print("Required margin:", requiredMargin);
  
   return requiredMargin;
}
  
//---- Trailing Stops
/*
* This method now includes check of open price and change of TP and SL in case of open slippage
* more than maxSlipPoints
* so risk/reward ratio will be kept after opder has been opened.
* Logic regarding this changes should be done only once for each order
*/
void TrailStop(double ts,double step,double be,double pl)
{
   int    k, error, total = OrdersTotal();
   bool   result;
   double Gain, BuyStop, SellStop;
   
   minstop  = MarketInfo(Symbol(),MODE_STOPLEVEL)/dRatio;
   
   for(int cnt=total-1;cnt>=0;cnt--)
   {
      if(!OrderSelect(cnt, SELECT_BY_POS)) continue;  
      if(OrderMagicNumber() != Magic || OrderSymbol() != Symbol()) continue;
      
      double open = OrderOpenPrice();
      double stop = OrderStopLoss();
      
      if(OrderType() == OP_BUY)
      {
         double SL = NormalizeDouble( OrderOpenPrice() - (InitialStop*_point),Digits);
         double TP = NormalizeDouble( OrderOpenPrice() + (TakeProfit*_point),Digits);
         
         double slip = NormalizeDouble((SL - OrderStopLoss())/_point,0);
         
         if( OrderStopLoss() != SL && slip > maxSlipPoints ){
            //on open price slippage SL, TP is not updated properly by the server
            //put correct stop loss & take profit into the order before it hits wrong targets
            //TODO write execution log file
            if(PrintInLog) Print("Ticket: ", OrderTicket() ," opened price slipped ", slip/10, " pips. TP and SL will be corrected: TP=",TP," SL=",SL);
            
            for(k = 0 ; k < TriesNum; k++)
            {
               result = OrderModify(OrderTicket(),open,SL,TP,0,Lime);
               
               error = GetLastError();
            
               if((error == 0 && result) || error == 1) break;
               else if(error == 130 && !result)
               {
                  Print("Error 130: ticket "+OrderTicket()+" openPrice="+open+" OrderStopLoss()="+OrderStopLoss()+" SL="+NormalizeDouble(SL,Digits));
                  RefreshRates();
                  result = OrderModify(OrderTicket(),open,SL,OrderTakeProfit(),0,Lime);
               }
               else {
                  Sleep(RetryTime);
                  RefreshRates();
                  continue;
               }
            }
         }
         
         BuyStop = 0;
   	   Gain = NormalizeDouble((Bid - open)/_point,Digits);
   	   
   	   if(DeltaTP>0 && MoveSL>0 && (OrderTakeProfit() - Bid)/_point <= DeltaTP)
   	   {
   	      BuyStop = NormalizeDouble(Bid - MoveSL*_point,Digits);
   	      TP = NormalizeDouble(OrderTakeProfit() + DeltaTP*_point,Digits);
         }
         else if(be > 0 && Gain >= be)
		   {
            BuyStop = NormalizeDouble(open + pl*_point,Digits);
		   }
			else if(ts > 0 || step > 0)
			{
			   BuyStop = NormalizeDouble(Bid - ts*_point,Digits);
			   if(step > 0 && stop > 0)
			   {
   			   if(BuyStop >= NormalizeDouble(stop + step *_point,Digits)) BuyStop = BuyStop; //???? what is that????
   			   else BuyStop = OrderStopLoss();
			   }
			}
			
			if(BuyStop <= 0) continue;
				   
			if(Bid - BuyStop < minstop*_point) BuyStop = NormalizeDouble(Bid - minstop*_point,Digits);  
              
			if(NormalizeDouble(OrderOpenPrice(),Digits) <= BuyStop)
         {
			   if(NormalizeDouble(BuyStop,Digits) > NormalizeDouble(stop,Digits) || stop == 0)
			   {
			      for(k = 0 ; k < TriesNum; k++)
               {
                  result = OrderModify(OrderTicket(),open,NormalizeDouble(BuyStop,Digits),TP,0,Lime);
                  
                  error = GetLastError();
               
                  if(error == 0 && result) break;
                  else 
                  if(error == 130 && !result)
                  {  
                     Print("Error "+GetLastError()+": ticket "+OrderTicket()+" openPrice="+open+" OrderSL="+OrderStopLoss()+" BuyStop="+NormalizeDouble(BuyStop,Digits)+" OrderTP="+OrderTakeProfit()+" TP="+TP);
                     RefreshRates();
                     if(Bid - BuyStop < minstop*_point) BuyStop = NormalizeDouble(Bid - minstop*_point,Digits); 
                     result = OrderModify(OrderTicket(),open,NormalizeDouble(BuyStop,Digits),TP,0,Lime);
                  }
                  else {
                     Sleep(RetryTime);
                     RefreshRates();
                     continue;
                  }
               }            
            }
         }
      }         
      else if(OrderType() == OP_SELL)
      {
         double SL = NormalizeDouble( OrderOpenPrice() + (InitialStop*_point),Digits);
         double TP = NormalizeDouble( OrderOpenPrice() - (TakeProfit*_point),Digits);
         
         double slip = NormalizeDouble((OrderStopLoss() - SL)/_point,0);
            
         if( OrderStopLoss() != SL && slip > maxSlipPoints ){ // if order slipped more tnan maxSlipPoints
            //on open price slippage SL, TP is not updated properly by the server
            //put correct stop loss take profit into the order before it hits wrong targets
            //TODO write execution log file
            if(PrintInLog) Print("Ticket: ", OrderTicket() ," opened price slipped ", slip, " points. TP and SL will be corrected: TP=",TP," SL=",SL);
            
            for( k = 0 ; k < TriesNum; k++)
            {
               result = OrderModify(OrderTicket(),open,SL,TP,0,Orange);
                  
               error = GetLastError();
               
               if((error == 0 && result) || error == 1) break;
               else 
               if(error == 130 && !result)
               {
                  Print("Error 130: ticket "+OrderTicket()+" openPrice="+open+" OrderStopLoss()="+OrderStopLoss()+" SL="+NormalizeDouble(SL,Digits));
                  RefreshRates();
                  result = OrderModify(OrderTicket(),open,NormalizeDouble(SL,Digits),TP,0,Orange);
               }
               else {
                  Sleep(RetryTime);
                  RefreshRates();
                  continue;
               }
            }
         }
      
         SellStop = 0;
         Gain = NormalizeDouble((open - Ask)/_point,Digits);
         
         if(DeltaTP>0 && MoveSL>0 && (Ask - OrderTakeProfit())/_point <= DeltaTP)
         {
   	      BuyStop = NormalizeDouble(Ask + MoveSL*_point,Digits);
   	      TP = NormalizeDouble(OrderTakeProfit() - DeltaTP*_point,Digits);
         }
         else if(be > 0 && Gain >= be)
			{
   			SellStop = NormalizeDouble(open - pl*_point,Digits);
			}
			else if(ts > 0 || step > 0)
			{
			   SellStop = NormalizeDouble(Ask + ts*_point,Digits);
			   
			   if(step > 0 && stop > 0)
			   {
   			   if(SellStop <= NormalizeDouble(stop - step *_point,Digits)) SellStop = SellStop;//??? what is that ???
   			   else SellStop = stop;
			   }
         }
                       
         if(SellStop <= 0) continue;
                        
         if(SellStop - Ask < minstop*_point) SellStop = NormalizeDouble(Ask + minstop*_point,Digits);   
                        
         if(NormalizeDouble(open,Digits) >= SellStop && SellStop > 0)
         {
            if(NormalizeDouble(SellStop,Digits) < NormalizeDouble(stop,Digits) || stop == 0)
            {
               for( k = 0 ; k < TriesNum; k++)
               {
                  result = OrderModify(OrderTicket(),open,NormalizeDouble(SellStop,Digits),NormalizeDouble(TP,Digits),0,Orange);
                     
                  error = GetLastError();
                  
                  if(error == 0 && result) break;
                  else 
                  if(error == 130 && !result)
                  {
                     Print("Error "+GetLastError()+": ticket "+OrderTicket()+" openPrice="+open+" OrderSL="+OrderStopLoss()+" SellStop="+NormalizeDouble(SellStop,Digits)+" OrderTP="+OrderTakeProfit()+" TP="+TP);
                     RefreshRates(); 
                     result = OrderModify(OrderTicket(),open,NormalizeDouble(SellStop,Digits),NormalizeDouble(TP,Digits),0,Orange);
                  }
                  else {
                     Sleep(RetryTime);
                     RefreshRates();
                     continue;
                  }
               }
   			}	    
         }
      }
   }     
}

//---- Open Sell Orders
int SellOrdOpen(int type,double price,double sl,double tp,int num)
{
   int ticket = 0, tr = 1;
   
   if(IsTesting() && tstFakeSlipPoints != 0) price -= tstFakeSlipPoints*_point;
   
   datetime expire = (datetime)(TimeCurrent() + OrderDuration);
   string comment = "Req. price: " + price+ " SELL:"+(string)num;
   
   if(IsTesting() || OrderDuration<600){
      expire = 0;
   }
   
   while(ticket <= 0 && tr <= TriesNum){
      ticket = OrderSend(Symbol(),type,lotAmount,
   	                   NormalizeDouble(price,Digits),
   	                   (int)(dRatio*Slippage),
   	                   NormalizeDouble(sl,Digits),
   	                   NormalizeDouble(tp,Digits),
   	                   comment,Magic,expire,Red);
      
	   if(ticket < 0){
	      if(GetLastError() > 0) Print("SELL: OrderSend failed with error #",ErrorDescription(GetLastError()));
         Sleep(RetryTime);
         RefreshRates();
         tr++;
      }else if(ticket > 0) 
      {
         SellNum[num-1] = 1;
         ECN_Sell = 0;
      }
   }   
   return(ticket);
}

//---- Open Buy Orders
int BuyOrdOpen(int type,double price,double sl,double tp,int num)
{
   int ticket = 0, tr = 1;
   
   if(IsTesting() && tstFakeSlipPoints != 0) price += tstFakeSlipPoints*_point;

   string comment = "Req. price: " + price + " BUY:"+(string)num;
   datetime expire = (datetime)(TimeCurrent()+OrderDuration);
   
   if(IsTesting() || OrderDuration<600){
     expire = 0;
   }
   
   while(ticket <= 0 && tr <= TriesNum){
      ticket = OrderSend(Symbol(),type,lotAmount,
   	                   NormalizeDouble(price,Digits),
   	                   (int)(dRatio*Slippage),
   	                   NormalizeDouble(sl,Digits), 
   	                   NormalizeDouble(tp,Digits),
   	                   comment,Magic,expire,Blue);
      
      if(ticket < 0){
	      if(GetLastError() > 0) Print("BUY : OrderSend failed with error #",ErrorDescription(GetLastError()));
         Sleep(RetryTime);
         RefreshRates();
         tr++;
      }else if(ticket > 0){
         BuyNum[num-1] = 1;
         ECN_Buy = 0;
      }
   }   
   
   return(ticket);
} 

//---- Scan Trades
int ScanTrades(int& buy,int& sell,int& buylimit,int& selllimit,int& buystop,int& sellstop)
{   
   buy = 0; sell = 0; buylimit = 0; selllimit = 0; buystop = 0; sellstop = 0;
     
   for(int cnt=0; cnt <OrdersTotal(); cnt++) 
   {        
   if(!OrderSelect(cnt, SELECT_BY_POS)) continue;            
   if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic) continue;  
      
      switch(OrderType()){
         case OP_BUY: buy++; break;
         case OP_SELL: sell++; break;
         case OP_BUYLIMIT: buylimit++; break;
         case OP_SELLLIMIT: selllimit++; break;
         case OP_BUYSTOP: buystop++; break;
         case OP_SELLSTOP: sellstop++; break;
      }     
   }
   
   return(buy + sell + buylimit + selllimit + buystop + sellstop);
}  

//-----   
datetime FinishTime(int duration)
{   
   int i, total = OrdersTotal();
   datetime finTime = 0;
         
   for(i=0;i<total;i++)
   {        
      if(!OrderSelect(i,SELECT_BY_POS)) continue;            
      if(OrderMagicNumber() != Magic || OrderSymbol() != Symbol()) continue;
       
      if(OrderType() <= OP_SELLSTOP) finTime = (datetime)(OrderOpenTime() + duration);
   }
   
   return(finTime);
}

// Closing of Pending Orders      
bool PendOrdDel(int mode)
{
   bool result = false;
   
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber() != Magic || OrderSymbol() != Symbol()) continue;     
   
      if((mode == 0 || mode == 1) && OrderType() == OP_BUYSTOP)
      {  int ticket = OrderTicket();
         if(!OrderDelete( ticket ))
            Print("BUYSTOP: OrderDelete failed with error #",GetLastError());
         else
            clearBuyData(ticket);
      }
      
      if((mode == 0 || mode == 2) && OrderType() == OP_SELLSTOP)
      {  int ticket = OrderTicket();
         result = OrderDelete( ticket );
         if(!result) Print("SELLSTOP: OrderDelete failed with error #",GetLastError());
         else{
            clearSellData(ticket);
         }
      }
   }
   
   return(result);
}

void clearSellData(int ticket){
   for(int i=0; i<OrdersNum; i++){
       int storedTicket = (int)sellOrders[i][0]; 
       if(ticket == storedTicket){
       //clearing data for deleted order
           sellOrders[i][0]=0;
           sellOrders[i][1]=0;
           break;
       }
    }
}

void clearBuyData(int ticket){
   for(int i=0; i<OrdersNum; i++){
       int storedTicket = (int)buyOrders[i][0]; 
       if(ticket == storedTicket){
       //clearing data for deleted order
           buyOrders[i][0]=0;
           buyOrders[i][1]=0;//requested price
           break;
       }
    }
}  

//-----
bool ReadnPlotCalendar(string fName)
{
   int    i, k, handle, rating = 0;
   bool   rates = false;
   string sYear, sMon, sDay, info;
   
   
   ArrayResize(sDate       ,0);
   ArrayResize(sTime       ,0);
   ArrayResize(sCurrency   ,0);
   ArrayResize(sEvent      ,0);
   ArrayResize(sImportance ,0);
   ArrayResize(sActChange  ,0);
   ArrayResize(sActual     ,0);
   ArrayResize(sForecast   ,0);
   ArrayResize(sPrevChange ,0);
   ArrayResize(sPrevious   ,0);
         
   ArrayResize(dt          ,0);
   ArrayResize(sImpact     ,0);
   ArrayResize(country     ,0);
   
   Print("Reading calendar: " + fName);
   handle = FileOpen(fName,FILE_CSV|FILE_READ,';');
   
   if(handle == INVALID_HANDLE)
   {
   Print("File open error ", GetLastError());
   return(false);
   }
   else
   {
   Print("File was opened ok... Reading");
   i = 0;
   int line=0;
   
      while(!FileIsEnding(handle))
      {
      
      k = ArraySize(sDate);
   
      ArrayResize(sDate       ,k + 1);
      ArrayResize(sTime       ,k + 1);
      ArrayResize(sCurrency   ,k + 1);
      ArrayResize(sImportance ,k + 1);
      ArrayResize(sEvent      ,k + 1);
      ArrayResize(sActChange  ,k + 1);
      ArrayResize(sActual     ,k + 1);
      ArrayResize(sForecast   ,k + 1);
      ArrayResize(sPrevChange ,k + 1);
      ArrayResize(sPrevious   ,k + 1);
            
      ArrayResize(dt          ,k + 1);
      ArrayResize(event       ,k + 1);
      ArrayResize(sImpact     ,k + 1);
      ArrayResize(country     ,k + 1);
      
      
      sDate[i]       = FileReadString(handle);           // Date
       //  Print("TRACE: sDate[i]="+sDate[i]);
      sTime[i]       = FileReadString(handle);           // Time
       //  Print("TRACE: sTime[i]="+sTime[i]);
      sCurrency[i]   = FileReadString(handle);           // Currency
      //   Print("TRACE: sCurrency[i]="+sCurrency[i]);
      sImportance[i] = FileReadString(handle);           // Importance
       //  Print("TRACE: sImportance[i]="+sImportance[i]);
      sEvent[i]      = FileReadString(handle);           // Event
       //  Print("TRACE: sEvent[i]="+sEvent[i]);
      sActChange[i]  = FileReadString(handle);           // Actual value change
       //  Print("TRACE: sActChange[i]="+sActChange[i]);
      sActual[i]     = FileReadString(handle);           // Actual value
       //  Print("TRACE: sActual[i]="+sActual[i]);
      sForecast[i]   = FileReadString(handle);           // Forecast value
       //  Print("TRACE: sForecast[i]="+sForecast[i]);
      sPrevChange[i] = FileReadString(handle);           // Previous value change
       //  Print("TRACE: sPrevChange[i]="+sPrevChange[i]);
      sPrevious[i]   = FileReadString(handle);           // Previous value
       //  Print("TRACE: sPrevious[i]="+sPrevious[i]);
     
      string last = FileReadString(handle);
      line++;
      //Print("TRACE: Last read from line "+line+" (parsing CSV): "+last);
      //Sleep(200);
      if(StringFind(sTime[i],":",0) < 0){
       //Print("TRACE: unable to find hh:mm separator! line "+line);
       continue;
      }
      
      if(sImportance[i] == "L") sImpact[i] = "L";
      if(sImportance[i] == "M") sImpact[i] = "M";
      if(sImportance[i] == "H") sImpact[i] = "H";  
      
      if(!ImpactFilter(sImpact[i])){ 
      //Print("TRACE: Unable to find importance. line " + line);
      continue;
      }
    
      color clr  =-1;//clrNONE;
      country[i] =-1;
      
      if(OnlySymbolNews && (StringSubstr(Symbol(),0,3)==sCurrency[i]) || (StringSubstr(Symbol(),3,3)==sCurrency[i])){
         country[i] = 1;
         if(sImportance[i] == "L") clr=LowColor;
         if(sImportance[i] == "M") clr=MidleColor;
         if(sImportance[i] == "H") clr=HighColor;
      }
      if(!OnlySymbolNews){
         if(sCurrency[i] == "USD" && USD != clrNONE) {country[i] = 1; clr = USD;} 
         if(sCurrency[i] == "EUR" && EUR != clrNONE) {country[i] = 1; clr = EUR;} 
         if(sCurrency[i] == "GBP" && GBP != clrNONE) {country[i] = 1; clr = GBP;} 
         if(sCurrency[i] == "JPY" && JPY != clrNONE) {country[i] = 1; clr = JPY;}
         if(sCurrency[i] == "AUD" && AUD != clrNONE) {country[i] = 1; clr = AUD;} 
         if(sCurrency[i] == "NZD" && NZD != clrNONE) {country[i] = 1; clr = NZD;} 
         if(sCurrency[i] == "CAD" && CAD != clrNONE) {country[i] = 1; clr = CAD;} 
         if(sCurrency[i] == "CHF" && CHF != clrNONE) {country[i] = 1; clr = CHF;} 
         if(sCurrency[i] == "CNY" && CNY != clrNONE) {country[i] = 1; clr = CNY;} 
      }
      
      if(country[i] < 0){
         //Print("TRACE: skip currency "+sCurrency[i]+" line " + line);
         continue;
      } 
           
      dt[i] = StrToTime(sDate[i] + " " + sTime[i]) + tz*3600;
      
      //if news time less than current tick time - skip old news
      if(IsTesting() && dt[i] < TimeCurrent()) continue;
      
      //while testing we must calculate daylight saving hour
      if(IsTesting() && !UseAutoTimeZone && isSummerDaylightSaving(dt[i])){
         dt[i] += 3600;//+1 hour while isDayLightSaving is true
      }
         
      if(StringSubstr(sEvent[i],0,3) != sCurrency[i]) event[i] = sEvent[i];
       else event[i] = StringSubstr(sEvent[i],4,0);
   
      info  = TimeToStr(dt[i]) + " " + sCurrency[i] + " " + event[i] + " " + sImpact[i] + " " + sActual[i] + " " + sForecast[i] + " " + sPrevious[i];
                    
      //if(PrintInLog) Print((string)(i+1) + " " + info);
                  
         if(country[i] > 0)
         {  
            string namePrefix = uniqueName;
            
            if(IsTesting()) namePrefix="tst";
         
            if(DisplayLines)
            {         
               string linename = namePrefix + "line" + (string)i;
               ObjectCreate    (0,linename,OBJ_VLINE    ,0,dt[i],Close[0]);
               ObjectSetInteger(0,linename,OBJPROP_COLOR,      clr);                    
               ObjectSetInteger(0,linename,OBJPROP_STYLE,LineStyle);                    
               ObjectSetInteger(0,linename,OBJPROP_BACK ,     true);          
               ObjectSetString (0,linename,OBJPROP_TEXT ,     info);
               ObjectSetInteger(0,linename,OBJPROP_SELECTABLE,true);
            }
  
            if(DisplayText)
            {
               string textname = namePrefix + "text" + (string)i;
               ObjectCreate    (0,textname,OBJ_TEXT        ,0,dt[i],Close[0]);
               ObjectSetString (0,textname,OBJPROP_TEXT    ,  info);
               ObjectSetInteger(0,textname,OBJPROP_COLOR   ,   clr);
               ObjectSetInteger(0,textname,OBJPROP_FONTSIZE,     8);
               ObjectSetDouble (0,textname,OBJPROP_ANGLE   ,    90);
            }
            
            if(DisplayEvents)
            {         
               string eventname = namePrefix + "event" + (string)i;
               ObjectCreate    (0,eventname,OBJ_EVENT    ,0,dt[i],0);
               ObjectSetInteger(0,eventname,OBJPROP_COLOR,      clr);
               ObjectSetInteger(0,eventname,OBJPROP_BACK ,     true);
               ObjectSetString (0,eventname,OBJPROP_TEXT ,     info);
               ObjectSetInteger(0,eventname,OBJPROP_SELECTABLE,true);
            }
         }
      i++;
      }
   NewsNum = i;
   }
   
   FileClose(handle);
   if(IsTesting()) Print("File was closed ok");
   
   return(0);
}

//-----   
bool ImpactFilter(string impact)
{
	if(NewsImportance == "" || StringFind(NewsImportance,impact) >= 0) return(true);

	return(false);
}

//-----   
string ToUpper(string str) 
{
   ushort ch;
   int len = StringLen(str);
   
   for(int j=0;j<len;j++) 
   {
   ch = StringGetChar(str, j);
      
      if(ch >= 'a' && ch <= 'z') 
      {
      ch += 'A' - 'a'; 
      str = StringSetChar(str, j, ch);
      }
   }
   return(str);
}

//-----   
datetime GetWeekStart(datetime date)
{ 
   int weekday = TimeDayOfWeek(date); 
   datetime start = date;
   //there is no need to decrement if EA has not been restarted during weekend
   //So actually decrement happens only if current tick day is not Sunday
   if(weekday > 0){
      for (int i=weekday; i>0; i--) start = decDateOnDay(start);
   }
   
   return(start);
}

//-----   
datetime decDateOnDay(datetime date) 
{ 
  int ty = TimeYear(date); 
  int tm = TimeMonth(date); 
  int td = TimeDay(date); 
  int th = TimeHour(date); 
  int ti = TimeMinute(date); 
    
   td--; 
   if(td == 0)
   { 
   tm--; 
      if(tm == 0) 
      { 
      ty--;
      tm = 12;
      } 
    
   if(tm == 1 || tm == 3 || tm == 5 || tm == 7 || tm == 8 || tm == 10 || tm == 12) td = 31; 
   if(tm == 2) if(MathMod(ty,4) == 0) td = 29; else td = 28; 
   if(tm == 4 || tm == 6 || tm == 9 || tm == 11) td = 30;
   } 
  
   return(StrToTime((string)ty+"."+(string)tm+"."+(string)td));
}

//----
void ObjectDel(string name)
{
   int _GetLastError = 0;
   
   while(ObjFind(name,0,0) > 0)
   {
   int obtotal = ObjectsTotal();
      
      for(int i=0;i<obtotal;i++)
      {
         if(StringFind(ObjectName(i),name,0) >= 0)
         {
            if(!ObjectDelete(ObjectName(i)))
            {
            _GetLastError = GetLastError();
            Print( "ObjectDelete( \"",ObjectName(i),"\" ) - Error #", _GetLastError );
            }
         }
      }
   }
}

//-----
int ObjFind(string name,int start, int num)
{
   int cnt = 0;
   
   for (int i=0;i<ObjectsTotal();i++)
      if(StringFind(ObjectName(i),name,start) == num) cnt += 1;
   
   return(cnt);
}

//---- Close of Orders
bool CloseOrder(int mode)
{
   bool result = false; 
   int  total  = OrdersTotal();
   
   for(int i=0;i<total;i++)  
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber() != Magic || OrderSymbol() != Symbol()) continue; 
      
      if((mode == 0 || mode == 1) && OrderType() == OP_BUY ) result = CloseAtMarket(OrderTicket(),OrderLots(),Aqua);
      if((mode == 0 || mode == 2) && OrderType() == OP_SELL) result = CloseAtMarket(OrderTicket(),OrderLots(),Pink);
   }
   
   return(result);
}

//-----   
bool CloseAtMarket(int ticket,double lot,color clr) 
{
   bool result = false;
   int  ntr;
      
   int tries = 0;
   
   while(!result && tries < TriesNum) 
   {
      ntr = 0; 
      while(ntr < 5 && !IsTradeAllowed()) {ntr++; Sleep(RetryTime);}
         
      RefreshRates();
         
      result = OrderClose(ticket,lot,OrderClosePrice(),Slippage,clr);
      tries++;
   }
   
   if(!result) Print("Error closing order : ",ErrorDescription(GetLastError()));
   
   return(result);
}

datetime TimeToOpen()
{
   double procTime = ProcessTime;
   datetime oTime, result = 0;
   
   for (int i=currentNews_i; i<NewsNum; i++)
   { 
       oTime = (datetime)(dt[i] - SecBeforeNews);
   
      if(TimeCurrent() >= oTime && TimeCurrent() <= oTime + procTime)
      {
         result = oTime;
         currentNews_i = i;
         currEventInfo  = TimeToStr(dt[i]) + " " + sCurrency[i] + " " + event[i] + " " + sImpact[i] + " " + sActual[i] + " " + sForecast[i] + " " + sPrevious[i];
         int k=1;
         while(k<=5){
            if(dt[i]==dt[i+k]) currEventInfo += "\n\n" + TimeToStr(dt[i+k]) + " " + sCurrency[i+k] + " " + event[i+k] + " " + sImpact[i+k] + " " + sActual[i+k] + " " + sForecast[i+k] + " " + sPrevious[i+k];
            k++;
         }
         break;
      }
   }
      
   return(result);
}

//-----
bool IsNewEvent()
{
   bool result    = false;
   datetime oTime = 0;
        
   for (int i=currentNews_i;i<NewsNum;i++)
   { 
      oTime = (datetime)(dt[i] - SecBeforeNews);
      
      if(TimeCurrent() >= oTime && oTime > prevEventTime)
      {
         result     = true; 
         prevEventTime = oTime;
         currentNews_i = i;
         break;
      }
   }
   
   return(result);
}

//-----        
void TrailOppositeOrder(int mode)
{
   int    k, nt, error;  
   bool   result = false;
   double Gain   = 0, BuyPrice, mBuyPrice, mBuyStop, mBuyProfit, SellPrice, mSellPrice, mSellStop, mSellProfit;
    
   for (int cnt=0;cnt<OrdersTotal();cnt++)
   { 
   if(!OrderSelect(cnt, SELECT_BY_POS)) continue;  
   if(OrderMagicNumber() != Magic || OrderSymbol() != Symbol()) continue;
          
      if(mode == 1 && OrderType() == OP_BUYSTOP) 
      {
		   BuyPrice = MarketInfo(Symbol(),MODE_ASK);
		
         for(nt=1;nt<=OrdersNum;nt++)
         {
            if(VerifyComment(1,nt))
			   {
			   mBuyPrice = BuyPrice + (2*PendOrdGap + OrdersStep*(nt - 1))*_point;
		      if(InitialStop > 0) mBuyStop   = mBuyPrice - InitialStop*_point; else mBuyStop   = 0;
            if(TakeProfit  > 0) mBuyProfit = mBuyPrice + TakeProfit *_point; else mBuyProfit = 0; 
			   			     
               if(NormalizeDouble(OrderOpenPrice(),Digits) > NormalizeDouble(mBuyPrice,Digits) && OrderType() == OP_BUYSTOP) 
               {   
			         for(k=0;k<TriesNum;k++)
                  {
                     result = OrderModify(OrderTicket(),
                                          NormalizeDouble(mBuyPrice ,Digits),
                                          NormalizeDouble(mBuyStop  ,Digits),
   			                              NormalizeDouble(mBuyProfit,Digits),0,Aqua);
                     
                     error = GetLastError();
                  
                     if(error == 0) break; 
                     else 
                     {
                     Print("Error trail BUYSTOP # ",OrderComment()," order=",OrderType(),"! Price=",DoubleToStr(mBuyPrice,Digits)," Stop=",DoubleToStr(mBuyStop,Digits)," Take=",DoubleToStr(mBuyProfit,Digits));  
                     Sleep(RetryTime); 
                     RefreshRates(); 
                     continue;
                     }
                  }
               }            
            }
         }
      }
                  
// - SELL Orders          
      if(mode == 2 && OrderType() == OP_SELLSTOP)
      {
         SellPrice = MarketInfo(Symbol(),MODE_BID);  
         
         for(nt=1;nt<=OrdersNum;nt++)
         {
            if(VerifyComment(2,nt))
			   {
            mSellPrice = SellPrice - (2*PendOrdGap + OrdersStep*(nt - 1))*_point;
            if(InitialStop > 0) mSellStop   = mSellPrice + InitialStop*_point; else mSellStop   = 0;
            if(TakeProfit  > 0) mSellProfit = mSellPrice - TakeProfit *_point; else mSellProfit = 0;  	   
         
               if(NormalizeDouble(OrderOpenPrice(),Digits) < NormalizeDouble(mSellPrice,Digits) && OrderType() == OP_SELLSTOP) 
               {
                  for(k = 0;k<TriesNum;k++)
                  {
                     result = OrderModify(OrderTicket(),
                                          NormalizeDouble(mSellPrice ,Digits),
   			                              NormalizeDouble(mSellStop  ,Digits),
   			                              NormalizeDouble(mSellProfit,Digits),0,Magenta);
                     
                     error  = GetLastError();
                  
                     if(error == 0) break; 
                     else 
                     {
                     Print("Error trail SELLSTOP # ",OrderComment()," order=",OrderType(),"! Price=",DoubleToStr(mSellPrice,Digits)," Stop=",DoubleToStr(mSellStop,Digits)," Take=",DoubleToStr(mSellProfit,Digits));  
                     Sleep(RetryTime); 
                     RefreshRates(); 
                     continue;
                     }
                  }   
               }   
   			}	    
         }
      }
   }     
}

//-----   
bool VerifyComment(int mode, int num)
{
   int total   = OrdersTotal();
   bool result = false; 
      
   for(int cnt=0;cnt<total;cnt++) 
   {        
   if(!OrderSelect(cnt,SELECT_BY_POS)) continue;            
   if(OrderMagicNumber() != Magic || OrderSymbol() != Symbol()) continue;
      
      if(mode == 1 && OrderComment() == ExpertName + " BUY:" + (string)num)  
      {
      result = true;
      break;
      }
      
      if(mode == 2 && OrderComment() == ExpertName + " SELL:" + (string)num) 
      {
      result = true;
      break;
      }
   }
   
   return(result);
}                                   

//-----   
string economicCalendar()
{  //Download, parse, save to CSV 
   
   int      handle_htm, handle_csv, _GetLastError;
   string   calendarName = "", fileName = "", strHTM = "", strCSV = "";
   
   datetime StartWeek = GetWeekStart(TimeGMT());// + tz*3600);
   
   string StartDay, strStartWeek = TimeToStr(StartWeek);
      
   StartYear  = (string)TimeYear (StartWeek);
   if(TimeMonth(StartWeek) > 9) StartMonth = (string)TimeMonth(StartWeek); else StartMonth = "0" + (string)TimeMonth(StartWeek);
   if(TimeDay  (StartWeek) > 9) StartDay   = (string)TimeDay  (StartWeek); else StartDay   = "0" + (string)TimeDay  (StartWeek);
   
   string StartTime = StartYear + "." + StartMonth + "." + StartDay; 
   string CalName   = CalendarName + " " + StartTime;
   
   if(IsTesting()){//While in tester should read from a file IsTesting  while in real Demo test should be !IsTesting() to read from test events file
      CalName = TestCalName;
   } 
   
   if(ReadFromFile && !IsTesting()){Print("Reading news from local csv file: "+ CalendarDirectory + "\\" + CalName + ".csv");}
   
   if(!ReadFromFile && !IsTesting())//avoid download from internet while testing
   {//getting/parsing weekly news data from the Internet
   int handle = FileOpen(CalendarDirectory + "\\" + CalName + ".csv",FILE_READ|FILE_CSV,";");
   FileClose(handle);
   
   strHTM = "";
	
	strHTM = httpGET(WebAdress);
   
      if(strHTM != "" || StringFind(strHTM,"Access Denied",0) < 0) 
      {
         if(SaveHTMFormat)
         {
         handle_htm = FileOpen(CalendarDirectory + "\\" + CalName + ".htm",FILE_WRITE|FILE_CSV);   
            
            if(handle_htm > 0)
            {
            FileWrite(handle_htm,strHTM);
            FileClose(handle_htm);
            }
            else 
	         {
	         _GetLastError = GetLastError();
	            Print("LoadWeek() - FileOpen() Error #",_GetLastError,"!");
	         }
	      }   
	     
	   strCSV = "";
   
	   Print( "Saving weekly news info (", StartTime, "): to csv file..." );
	      
	   handle_csv = FileOpen(CalendarDirectory + "\\" + CalName + ".csv",FILE_WRITE|FILE_CSV,";");   
	   
	      if(ConvertHTMtoCSV(StartWeek,strHTM,strCSV))
	      {   
	         if(handle_csv > 0)
	         {
		      FileWrite(handle_csv,strCSV);
		      FileClose(handle_csv);
	         }
	         else
	         {
		      _GetLastError = GetLastError();
		      Print("LoadWeek() - FileOpen() Error #",_GetLastError,"!");
		      return("");
	         }
	      }   
	   }
	}   
   
   return(CalendarDirectory + "\\" + CalName);   
}

bool ConvertHTMtoCSV(datetime StartWeekTime,string htm,string& csv)
{
	int month = 0;
	string year, day, time;
	
	int table_start = StringFind(htm,"pageStartAt>")+12;
	int table_end	 = StringFind(htm,"</tbody>",table_start);
	
	if(IsTesting()){
	   Print("htm stringsize:" );
	}
	
	if(table_start < 0 || table_end < 0)
	{
   	Alert("ConvertHTMtoCSV(",TimeToStr(StartWeekTime,TIME_DATE),"): invalid htm format!");
   	return(false);
	}

	int curr_row = StringFind(htm,"<tr id=\"eventRow" ,table_start );//"<tr class=\"e-cal-row",table_start );
	int next_row = StringFind(htm,"<tr id=\"eventInfo",curr_row + 1);

	int	 rows_count	= 0;
	string rows[10000];//2621 High news for period 2015.01.01-2018.02.10

	while(curr_row >= 0 && curr_row < table_end)
	{
   	rows[rows_count] = StringSubstr(htm,curr_row,next_row - curr_row + 5);
   
   	rows_count ++;
      
   	curr_row = StringFind(htm,"<tr id=\"eventRow" ,curr_row + 1);
   	next_row = StringFind(htm,"<tr id=\"eventInfo",curr_row + 1);
	}
   
	if(rows_count <= 0)
	{
   	Alert("ConvertHTMtoCSV(",TimeToStr(StartWeekTime,TIME_DATE),"): invalid htm format (no rows in table)!" );
   	return(false);
	}
   string startweek = GetVal(rows[0],"event_timestamp=\"","\" onclick=");
   StringReplace(startweek,"-",".");
	datetime		curDayTime	= StringToTime(startweek);//StartWeekTime;
	
	
	for(int r=0;r<rows_count;r++)
	{
   	int	 columns_count	= 0;
   	string columns[999];
   
   	int curr_col = 0, next_col = 0;
   
		while(columns_count <= 8)
		{
   		if(columns_count == 0) {curr_col = StringFind(rows[r],"<tr id="); next_col = StringFind(rows[r],";\">");}
   		 else {curr_col = StringFind(rows[r],"<td class=",curr_col + 1); next_col = StringFind(rows[r],"</td>",curr_col + 1);} 
   		
   		columns[columns_count] = StringSubstr(rows[r],curr_col,next_col - curr_col + 5);
   	
   		if(columns_count == 0) next_col = StringFind(rows[r],";\">",curr_col + 1);
   		 else next_col = StringFind(rows[r],"</td>",curr_col + 1);
   		 
   		columns_count ++;
		}
 
		if(columns_count > 6)
		{
		   if(StringFind(columns[1],"center time") < 0) 
		   {
   		string timestamp = GetVal(columns[0],"event_timestamp=\"","\" onclick=");;
		   StringReplace(timestamp,"-",".");
		      
		   curDayTime = StringToTime(timestamp);
		
		   csv = StringConcatenate(csv,TimeToStr(curDayTime,TIME_DATE));
		
         time = TimeToStr(curDayTime,TIME_MINUTES);//GetVal(columns[0],">","</td>");
				
		   csv = StringConcatenate(csv,";",time);
			
  	      csv = StringConcatenate(csv,";",GetVal(columns[2],"</span> ","</td>"));
   		
		   string impact = GetVal(columns[3],"title=\""," Volatility");
		  
		      if(impact == "High"    ) impact = "H"; 
		      else 
		      if(impact == "Moderate") impact = "M";
		      else 
		      if(impact == "Low"     ) impact = "L";
		      else impact = "N";
         
         csv = StringConcatenate(csv,";",impact);   
		
		   string newevent = "";
		      
		      if(StringFind(columns[4],"Speech") > 0) newevent = GetVal(columns[4],"left event\">","                        &nbsp;");
		      else 
		      if(StringFind(columns[4],"Preliminary Release") > 0) newevent = GetVal(columns[4],"left event\">","&nbsp;");
		      else newevent = GetVal(columns[4],"left event\">", "</td>"); 
		
		   csv = StringConcatenate(csv,";",newevent);
		
		      if(StringFind(columns[5],"greenFont") > 0) csv = StringConcatenate(csv,";",">");
		      else 
		      if(StringFind(columns[5],"redFont"  ) > 0) csv = StringConcatenate(csv,";","<");
		      else csv = StringConcatenate(csv,";","=");
		
		   string actual = GetVal(columns[5],"\">","</td>");
		   if(actual == "&nbsp;") actual = "";  	      
         csv = StringConcatenate(csv,";",actual);
		
		  
		   string forecast = GetVal(columns[6],"\">","</td>");
		   if(forecast == "&nbsp;") forecast = ""; 
		   csv = StringConcatenate(csv,";",forecast);
      
            if(StringFind(columns[7],"greenFont") > 0) csv = StringConcatenate(csv,";",">");
		      else 
		      if(StringFind(columns[7],"redFont"  ) > 0) csv = StringConcatenate(csv,";","<");
		      else csv = StringConcatenate(csv,";","=");
		
		   string previous = GetVal(columns[7],"\">","</td>");
		   if(previous == "&nbsp;") previous = ""; 
		   csv = StringConcatenate(csv,";",previous);
		
		   csv = StringConcatenate(csv,";\n");
		   }
		}
	}
	
	return(true);
}

string GetVal(string text,string s_from,string s_to)
{
	int len  = StringLen(s_from);
	int pos1 = StringFind(text,s_from,0);
	int pos2 = StringFind(text,s_to,pos1 + 1);

	if(pos2 == pos1 + len)
	{
	return("");
	}
	else
	{
		if(pos1 >= 0 && pos2 >= 0)
		{
		string res = StringSubstr(text,pos1 + len,pos2 - (pos1 + len));
		if(StringFind(res,"&lt") >= 0) res = stringReplace(res,"&lt","<");
		return( res );
		}
		else return("GetValError");
	}
}

string stringReplace(string InputString,string MatchedText,string NewText )
{
	string res;
	string temp, source;
	string first, third;
	int    pos, matchLength, k;
	
	source  = InputString;
	NewText = NewText;

	matchLength = StringLen(MatchedText);
	k = 0;
	while(StringFind(source,MatchedText) != -1)
 	{
 	pos = StringFind(source,MatchedText);
 		if(pos != -1)
    	{
    	if(pos != 0) first = StringSubstr(source,0,pos); else first="";
    	third  = StringSubstr(source,pos + matchLength,StringLen(source) - pos - matchLength);
    	temp   = StringConcatenate(first,NewText,third);
    	source = temp;
    	k++;
    	if(k > 2000) break;
    	}
 	}
	res = source; 
	return(res); 
}

int monthToNum(string month)
{
   if(month == "January"   ) return( 1);
   if(month == "February"  ) return( 2);
   if(month == "March"     ) return( 3);
   if(month == "April"     ) return( 4);
   if(month == "May"       ) return( 5);
   if(month == "June"      ) return( 6);
   if(month == "July"      ) return( 7);
   if(month == "August"    ) return( 8);
   if(month == "September" ) return( 9);
   if(month == "October"   ) return(10);
   if(month == "November"  ) return(11);
   if(month == "December"  ) return(12);
   
   return(0);
}

//-----   
string ChartComment()
{
   int i;
   string sComment   = "";
   string sp1        = "________________________________________\n";
   string NL         = "\n";
   string upcomNews  = "";
   string upcomTime  = "";
   string prevNews   = "";
   string prevTime   = "";
   string nextNews   = "";
   string nextTime   = "";
   string currEvent  = "";
   string prevEvent  = "";
   
   int prTime = 0; 
   int upTime = 0;
   int nxTime = 0;
   
   for(i=currentNews_i;i<NewsNum;i++)
   { 
   //if(StringLen(event[i]) > MaxEventLength)  currEvent = StringSubstr(event[i],0,MaxEventLength-3 ) + "..."; else
    currEvent = event[i];
            
      if((i == 0 && (int)dt[i] > 0 && TimeCurrent() <= dt[i])||(i > 0 && (int)dt[i] > 0 && dt[i-1] < dt[i] && TimeCurrent() > dt[i-1] && TimeCurrent() <= dt[i])||((int)dt[i] > 0 && upTime == dt[i] && TimeCurrent() <= dt[i]))
      {
         if(upTime == dt[i] && event[i] != event[i-1])   
         {
         upcomNews = upcomNews + (sCurrency[i] + "  " + sImpact[i] + "  " + currEvent + NL + NL); 
         upcomTime = TimeToStr(upTime);  
         }
         else
         {
         upcomNews = sCurrency[i] + "  " + sImpact[i] + "  " + currEvent + NL + NL; 
         upcomTime = TimeToStr(dt[i]);  
         }
      upTime = (int)dt[i];
      }   
         
      if(i > 0 && TimeCurrent() > dt[i-1] && (int)dt[i-1] > 0)
      {
      //if(StringLen(event[i-1]) > MaxEventLength)  prevevent = StringSubstr(event[i-1],0,MaxEventLength-3 ) + "..."; else
       prevEvent = event[i-1];
          
         if(prTime == dt[i-1] && event[i-1] != event[i-2])   
         {
         
         prevNews = prevNews + (sCurrency[i-1]+"  " + sImpact[i-1] + "  " + prevEvent + NL + NL); 
         prevTime = TimeToStr(prTime);
         }
         else
         {
         prevNews = sCurrency[i-1] + "  " + sImpact[i-1] + "  " + prevEvent + NL + NL; 
         prevTime = TimeToStr(dt[i-1]);
         }
      
      if(i == 0) {prevNews =""; prevTime = "";}  
      prTime = (int)dt[i-1];
      }
            
      if((int)dt[i] > 0 && upTime > 0 && upTime < dt[i])
      {
         if(dt[i] > nxTime && nxTime > 0) break;
         if(nxTime == dt[i] && event[i] != event[i-1])
         {      
         nextNews = nextNews + (sCurrency[i]+ "  " + sImpact[i] + "  " + currEvent + NL + NL);
         nextTime = TimeToStr(nxTime);
         }
         else
         {
         nextNews = sCurrency[i]+"  " + sImpact[i] + "  " + currEvent + NL + NL;
         nextTime = TimeToStr(dt[i]);
         }
      nxTime = (int)dt[i];
      }
   }
   
   int buy, sell, buylimit, selllimit, buystop, sellstop;
   int total = ScanTrades(buy, sell, buylimit, selllimit, buystop, sellstop);
   
   sComment = sp1 + NL;
   sComment += "ExpertName : " + ExpertName+NL+NL;
   
   string timezoneText = "Broker\'s Name :  "+AccountCompany()+ NL + NL +"Time Zone : GMT";
   
   if(TimeZone >= 0)
     sComment += timezoneText + " + " + (string)tz + NL + NL;
   else
     sComment += timezoneText + " - " + DoubleToStr(MathAbs(tz),0) + NL + NL;
     
   sComment +=  "Leverage: " + IntegerToString(AccountLeverage()) + NL + sp1 + NL;
   
   sComment +=  "Time: " + TimeToStr(TimeCurrent()) + NL + NL;
   
   sComment +=  "Current Lot size: " + DoubleToStr(lotAmount,2) + NL + NL;
   
   if(ShowCalendar)
   {
      sComment += "  NEWS :" + NL + NL;
      sComment += "- Previous  :  "   + prevTime  + NL + sp1 + NL + prevNews  + NL + NL;
      sComment += "- Upcoming :  "    + upcomTime + NL + sp1 + NL + upcomNews + NL + NL;
      sComment += "- Next        :  " + nextTime  + NL + sp1 + NL + nextNews  + NL + sp1 + NL;
   }
   
   //sComment = sComment + "prevTime=" + TimeToStr(prevEventTime) + " NewEvent=" + (string)NewEvent + NL;   
   
   string smins, ssecs;
   
   if(ECN_Mode)
   {
      if(OpenTime > 0)
      { 
         int mins = (int)(MathFloor(((OpenTime + OrderDuration) - TimeCurrent())/60.0));
         int secs = (int)(OpenTime + OrderDuration - TimeCurrent() - mins*60);
         
         if(mins < 10) smins = StringConcatenate("0",mins); else smins = (string)mins; 
         if(secs < 10) ssecs = StringConcatenate("0",secs); else ssecs = (string)secs;
         
         sComment += "ACTIVE from " + TimeToStr(OpenTime,TIME_SECONDS) +"  "+ smins +":"+ ssecs + " min left";
      }
      else 
         sComment += "NOT ACTIVE";
   }
   
   sComment = getStatistics( sComment );
   
   Comment(sComment);

   return sComment;
}

string getStatistics(string sComment){
   string sp1        = "________________________________________\n\n";
   string NL         = "\n";
   string pip = " Pips";
   string bestExec = "   Best execution ";
   if(priceImpCounter > 0)
   {  
      sComment += "Open Price Improvement (+) or Slippage (-)" + NL + NL;
      sComment += "Min " + DoubleToString(minOpenPriceImprovement, 1) + pip + "  ticket #" + minOpenPriceImprovmentTicket + NL + NL;
      sComment += "Max " + DoubleToString(maxOpenPriceImprovement, 1) + pip + "  ticket #" + maxOpenPriceImprovmentTicket + NL + NL;
      sComment += "Avg " + DoubleToString(avgOpenPriceImprovement, 1) + pip + NL + NL;
      sComment += "Activated Orders " + priceImpCounter + bestExec + openPriceImprovedPerc + " %" + NL;
      sComment += sp1;
   }
   

   
   if(tpCounter > 0)
   {
      sComment += "TP Improvement (+) or Slippage (-)" + NL;
      sComment += "Min " + DoubleToString(minTPImprovement, 1) + pip + "  ticket #" +  minTPImprovmentTicket + NL + NL;
      sComment += "Max " + DoubleToString(maxTPImprovement, 1) + pip + "  ticket #" + maxTPImprovmentTicket + NL + NL;
      sComment += "Avg " + DoubleToString(avgTPImprovement, 1) + pip + NL + NL;
      sComment += "TP Orders " + tpCounter + bestExec + tpImprovedPerc + " %" + NL;
      sComment += sp1;
   }
   
   if(slCounter > 0)
   {
      sComment += "SL Improvement (+) or Slippage (-)" + NL + NL;
      sComment += "Min " + DoubleToString(minSLImprovement, 1) + pip + "  ticket #" + minSLImprovmentTicket + NL + NL;
      sComment += "Max " + DoubleToString(maxSLImprovement, 1) + pip + "  ticket #" + maxSLImprovmentTicket + NL + NL;
      sComment += "Avg " + DoubleToString(avgSLImprovement, 1) + pip + NL + NL;
      sComment += "SL Orders " + slCounter + bestExec + slImprovedPerc +" %" + NL;
      sComment += sp1;
   }
   
   if(spreadCnt > 0 )
   {
      sComment += "Spread Stats" + NL + NL;
      sComment += "Min " + DoubleToString(minSpread, 1) + pip + NL + NL;
      sComment += "Max " + DoubleToString(maxSpread, 1) + pip + NL + NL;
      sComment += "Avg " + DoubleToString(avgSpread, 1) + pip + NL + NL;
      sComment += "Ticks " + spreadCnt + NL;
      sComment += sp1;
   }
   
   if(spreadCntLE > 0 )
   {
      sComment += "Spread during last News" + NL + NL;
      sComment += "Min " + DoubleToString(minSpreadLE, 1) + pip + NL + NL;
      sComment += "Max " + DoubleToString(maxSpreadLE, 1) + pip + NL + NL;
      sComment += "Avg " + DoubleToString(avgSpreadLE, 1) + pip + NL + NL;
      sComment += "Ticks " + spreadCntLE + NL;
      sComment += sp1;
   }
   
   sComment += "Account Change  " + DoubleToString(changePL, 2) + " %" + NL + NL;
   sComment += "After Last Event  " + DoubleToString(changeAfterLastEvent, 2) + " %" + NL + NL;
   
   if(minMarginLevel!=DBL_MAX){
      sComment += "Min Margin Level  " + DoubleToString(minMarginLevel, 2) + " %" + NL;
   }
   
   return sComment;
}

//-----   
void ECN_StopAndProfit()
{
   int    k, error;
   bool   result = false;
   double spread = Ask - Bid, BuyStop, BuyProfit, SellStop, SellProfit;
       
   for (int cnt=0;cnt<OrdersTotal();cnt++)
   { 
   if(!OrderSelect(cnt,SELECT_BY_POS)) continue;   
   if(OrderMagicNumber() != Magic || OrderSymbol() != Symbol()) continue;
   
   int mode = OrderType();    
      
      if((mode == OP_BUY || mode == OP_BUYLIMIT || mode == OP_BUYSTOP) && ECN_Buy != OrderTicket()) 
      {
		   if(InitialStop > 0) BuyStop   = OrderOpenPrice() - InitialStop*_point; else BuyStop   = OrderStopLoss();
         if(TakeProfit  > 0) BuyProfit = OrderOpenPrice() + TakeProfit *_point; else BuyProfit = OrderTakeProfit();  
			
		BuyStop   = NormalizeDouble(BuyStop  ,Digits);
		BuyProfit = NormalizeDouble(BuyProfit,Digits);     
			   
		   if((OrderStopLoss() == 0 && BuyStop > 0)||(OrderTakeProfit() == 0 && BuyProfit > 0)) 
         {   
			   for(k=0;k<TriesNum;k++)
            {
            result = OrderModify(OrderTicket(),NormalizeDouble(OrderOpenPrice(),Digits),
			                        BuyStop,
			                        BuyProfit,0,Lime);
      
            error = GetLastError();
               
               if(error == 0) 
               {
               ECN_Buy = OrderTicket(); 
               break;
               }
               else 
               {
               Print("BUY: OrderModify failed with error #",ErrorDescription(GetLastError()));
               Sleep(RetryTime); 
               RefreshRates(); 
               continue;
               }
            }            
         }
      }   
// - SELL Orders          
      if((mode == OP_SELL || mode == OP_SELLLIMIT || mode == OP_SELLSTOP) && ECN_Sell != OrderTicket())
      {
         if(InitialStop > 0) SellStop   = OrderOpenPrice() + InitialStop*_point; else SellStop   = OrderStopLoss();
	      if(TakeProfit  > 0) SellProfit = OrderOpenPrice() - TakeProfit*_point;  else SellProfit = OrderTakeProfit();
			               
      SellStop   = NormalizeDouble(SellStop,Digits);
		SellProfit = NormalizeDouble(SellProfit,Digits);    
            
         if((OrderStopLoss() == 0 && SellStop > 0)||(OrderTakeProfit() == 0 && SellProfit > 0)) 
         {
            for(k=0;k<TriesNum;k++)
            {
            result = OrderModify(OrderTicket(),NormalizeDouble(OrderOpenPrice(),Digits),
			                        SellStop,
			                        SellProfit,0,Orange);
            
            error = GetLastError();
               
               if(error==0) 
               {
               ECN_Sell = OrderTicket(); 
               break; 
               }
               else 
               {
               Print("SELL: OrderModify failed with error #",ErrorDescription(GetLastError()));
               Sleep(RetryTime); 
               RefreshRates(); 
               continue;
               }
            }   
   		}	    
      }
   }     
}

//-----   
string FormatDateTime(int nYear,int nMonth,int nDay,int nHour,int nMin,int nSec)
{
   string sMonth,sDay,sHour,sMin,sSec;
//----
   sMonth = (string)(100 + nMonth);
   sMonth = StringSubstr(sMonth,1);
   sDay   = (string)(100 + nDay);
   sDay   = StringSubstr(sDay,1);
   sHour  = (string)(100 + nHour);
   sHour  = StringSubstr(sHour,1);
   sMin   = (string)(100 + nMin);
   sMin   = StringSubstr(sMin,1);
   sSec   = (string)(100 + nSec);
   sSec   = StringSubstr(sSec,1);
//----
   return(StringConcatenate(nYear,".",sMonth,".",sDay," ",sHour,":",sMin,":",sSec));
}   

//-----   
#import "wininet.dll"
int InternetOpenW(string sAgent, int lAccessType=0, string sProxyName="", string sProxyBypass="", uint lFlags=0);
int InternetOpenUrlW(int hInternetSession, string sUrl, string sHeaders="", int lHeadersLength=0, uint lFlags=0, int lContext=0);
int InternetReadFile(int hFile, uchar& sBuffer[], int lNumBytesToRead, int& lNumberOfBytesRead[]);
int InternetCloseHandle(int hInet);
#import

#define INTERNET_FLAG_PRAGMA_NOCACHE    0x00000100 // Tell proxy not to read cache
#define INTERNET_FLAG_NO_CACHE_WRITE    0x04000000 // Don't write cache
#define INTERNET_FLAG_RELOAD            0x80000000 // Don't read cache
#define INTERNET_AGENT                  "Mozilla/4.0 (compatible; MT4-News/1.0;)"
#define INTERNET_READ_BUFFER_SIZE       4096

string httpGET(string url)
{
   uint flags = INTERNET_FLAG_NO_CACHE_WRITE | INTERNET_FLAG_PRAGMA_NOCACHE | INTERNET_FLAG_RELOAD;
   int inetsesshandle = InternetOpenW(INTERNET_AGENT);
   
   if(inetsesshandle == 0) return("Error: InternetOpen");
  
   int ineturlhandle = InternetOpenUrlW(inetsesshandle,url,NULL,0,flags);
  
   if(ineturlhandle == 0) {InternetCloseHandle(inetsesshandle); return("Error: InternetOpenUrl");}
  
   int lreturn[1], ineterr = 0;
   uchar buffer[INTERNET_READ_BUFFER_SIZE];
   string content = "";
  
   while (!IsStopped())
   {
      if(InternetReadFile(ineturlhandle,buffer,INTERNET_READ_BUFFER_SIZE,lreturn) == 0){content="Error: InternetReadFile"; break;}
      
      if(lreturn[0] <= 0) break;
      content = content + CharArrayToString(buffer,0,lreturn[0],CP_ACP);
   }
   
   InternetCloseHandle(ineturlhandle);
   InternetCloseHandle(inetsesshandle);
   
   return(content);
}
               
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//---- 
  if(!IsTesting()){
      PendOrdDel(0);
      ObjectDel(uniqueName);
      Comment("");
   }
//----
   
   return(0);
  }
  
  
void calcSpreadStatistics(){
    double spread = MarketInfo(Symbol(), MODE_SPREAD)/10; //pips
    spreadSum += spread; spreadSumLE += spread;

    spreadCnt++; spreadCntLE++;
    
    minSpread = MathMin(minSpread,spread);
    maxSpread = MathMax(maxSpread,spread);
    avgSpread = spreadSum/spreadCnt;
    
    minSpreadLE = MathMin(minSpreadLE,spread);
    maxSpreadLE = MathMax(maxSpreadLE,spread);
    avgSpreadLE = spreadSumLE/spreadCntLE;
}
  
  
double tradeProfitLoss, balanceBeforeTrade;
string NewsName, NewsForecast, NewsPrevious;

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
   dRatio = 1; //5 digits//MathPow(10,Digits%2);
   _point = MarketInfo(Symbol(),MODE_POINT)*dRatio;
   tick_val = MarketInfo(Symbol(),MODE_TICKVALUE)*dRatio;
   lotAmount = MoneyManagement(MM_Mode);

   //if(iBars(Symbol(),0) < 100) {Print("Bars=",iBars(Symbol(),0)," < 100!"); return(0);}
   if(GetLastError() == 134)   {Print("Not enough money for new orders. Free Margin = ", AccountFreeMargin()); return(0);}
   if(!IsTradeAllowed())    {Print("Error: Trading is not currently allowed!"); return(0);}
   if(IsTradeContextBusy()) {Print("Trade context is busy. Please wait"); return(0);}

//---- 
   if(UseAutoTimeZone)
   {
      if(counter == 0) { //should not wait another tick
         TimeCurrent();
         counter++;
         Comment(""); 
      }
   }
     
   if(currentWeekTime == NULL){
      currentWeekTime = iTime(NULL,PERIOD_W1,0);
   }         
 
   if(firstTime){
      if(UseAutoTimeZone) tz = (int)MathMin(NormalizeDouble((TimeCurrent() - TimeGMT())/3600.0,0),24);
      else tz = TimeZone; 
   }
 
   bool isNewWeekStarted = TimeCurrent() - currentWeekTime >= PERIOD_W1*60;
 
   if( firstTime || isNewWeekStarted )
   {
      string calName = economicCalendar();//download, parse, convert to CSV file

      currentNews_i = 0; //reset news counter on new week
   
      if(calName != "")
      {
         ObjectDel(uniqueName);
         string fileName = calName + ".csv";
         
         if(IsTesting() && firstTime){
            //while testing we reading all news events from a single file
            Print("TRACE: ReadnPlotCalendar call");
            ReadnPlotCalendar(fileName);
         }
         if(!IsTesting()){
            //applying news events info for a new week
            ReadnPlotCalendar(fileName);
         }

         firstTime    = false;
         //update current week start time
         currentWeekTime = iTime(NULL,PERIOD_W1,0);
      }
      else 
      {  Print("Error: empty calendar name - unable to read and plot news on chart");
         return(0);
      }
   }
   
   //===========================  ORDERS OPEN LOGIC ===================================
   
   int buy, sell, buylimit, selllimit, buystop, sellstop, cnt;
   int trades  = ScanTrades(buy, sell, buylimit, selllimit, buystop, sellstop);
   int open    = buy + sell;
   int pending = buylimit + buystop + selllimit + sellstop;
   
   //clarifying/processing order events
   CheckEvents(Magic);
   
   if(open >0 ){
      double marginLevel = AccountEquity()/AccountMargin()*100;
      minMarginLevel = MathMin(minMarginLevel, marginLevel);
      if(pndOrdersSent==true) shouldSendEmail = true;
   }
   
   if(trades>0){
       calcSpreadStatistics();
   }
   
   if(trades==0 && shouldSendEmail == true){
      if(!IsTesting()) writeProperties();
      sendEmailNotification();
      writeEventInfo();
      pndOrdersSent = false;
      shouldSendEmail = false;
      emailDetailedStats = "";
   }
   
   NewEvent = IsNewEvent();
   
   if(ShowComments && trades==0)//don't update comments while open orders exists to improve performance
      ChartComment();
   
   //if(IsTesting()){
   //strategy tester does not support expiration of pending orders - delete them while testing
   //pending orders does not support expiration less than 11 minutes - so apply the same for real/demo trading
   //not just testing
   //delete pending orders if they expired
      datetime FinTime = FinishTime(OrderDuration);
      if(TimeCurrent() >= FinTime) PendOrdDel(0);
   //}
   
   if(buy >0 || sell > 0)
   {  //TrailStop now includes SL/TP correction when open price slipped, BreakEven must be set non zero
      //so we will set correct SL/TP first and after that opposite pending orders deletions
      // which could ~3 sec 
      if(open > 0 && (TrailingStop > 0 || BreakEven > 0)) TrailStop(TrailingStop,TrailingStep,BreakEven,PipsLock);

      if(DeleteOpposite)
      {
         if(buy  > 0) PendOrdDel(2); //remove pending sell orders
         if(sell > 0) PendOrdDel(1); //remove pending buy orders 
          
         if(open == 0 && (buystop == 0 || sellstop == 0)) PendOrdDel(0);
      }      

      datetime EndTime = StrToTime(SessionEndTime);
      
      bool EOD = false;
      EOD = TimeCurrent() >= EndTime;
      
      if(NewEvent || EOD)
      {
         while(trades > 0) 
         {
            if(CloseOnNewEvent) CloseOrder(0); 
            PendOrdDel(0);
            trades = ScanTrades(buy, sell, buylimit, selllimit, buystop, sellstop);
         }
         //analyzing last news trade P/L
         tradeProfitLoss = AccountBalance() - balanceBeforeTrade;
         
         if(tradeProfitLoss != 0){
            analizeNewsTrade();
         }
         else{
            Print("Balance is the same");
         }
      }
     
      if(ECN_Mode && trades > 0) ECN_StopAndProfit();
   
      if(TrailOpposite && !DeleteOpposite)
      {
         if(buy  > 0 && sellstop > 0) TrailOppositeOrder(2); 
         if(sell > 0 && buystop  > 0) TrailOppositeOrder(1);
      }   
   }
   
   if(ECN_Mode && NewEvent && trades < 1)
   {
      BuyEvent  = 0; 
      SellEvent = 0; 
         
         for(cnt=0;cnt<OrdersNum;cnt++)
         {
            BuyNum[cnt]  = 0;
            SellNum[cnt] = 0;    
         }   
      
      ObjectDel(uniqueName + " arr");
   }
         
   double BuyStop, BuyProfit, SellStop, SellProfit;

//   if(IsTesting() && TimeCurrent()>= traceTime  && TimeCurrent()< traceEnd)
//   Print("timestamp:"+TimeToString(TimeCurrent())+" TRACE: pending:"+pending+" trades:"+trades+" ECN_Mode:"+ECN_Mode);

   if((!ECN_Mode && pending ==0) || (ECN_Mode && trades == 0))
   {

     OpenTime = TimeToOpen();
//   if(IsTesting() && TimeCurrent()>= traceTime  && TimeCurrent()<=traceEnd)
//   Print("timestamp:"+TimeToString(TimeCurrent())+" TRACE: TimeToOpen():"+TimeToString(OpenTime));
   
      if(OpenTime !=0 )
      {
          //reset last event event speard stats
          minSpreadLE = DBL_MAX;
          maxSpreadLE = DBL_MIN;
          avgSpreadLE = 0;
          spreadSumLE = 0;
          spreadCntLE = 0;
       
         equityBeforeEvent = AccountEquity();
         pndOrdersSent = true;
         
         double BuyPrice;
         double SellPrice;
      
         if(CandlesToCheck==0){
            BuyPrice = Ask;
            SellPrice = Bid;
         }else{
            double h=iHigh(NULL,0,0);
      		double l=iLow(NULL,0,0);
      		int i;
      		for (i=1;i<=CandlesToCheck;i++) if (iHigh(NULL,0,i-1)>h) h=iHigh(NULL,0,i-1);
      		for (i=1;i<=CandlesToCheck;i++) if (iLow(NULL,0,i-1)<l) l=iLow(NULL,0,i-1);
      		
      		BuyPrice=h;
      		SellPrice=l;
         }
         //opening new stop orders
         balanceBeforeTrade = AccountBalance();
         NewsName = sEvent[currentNews_i];
         NewsForecast = sForecast[currentNews_i];
         NewsPrevious = sPrevious[currentNews_i];
         
         for(cnt=1;cnt<=OrdersNum;cnt++)
         {
            if(!ECN_Mode)
		      {
   		      double oBuyPrice = BuyPrice + (PendOrdGap + OrdersStep*(cnt - 1))*_point;
   		      if (InitialStop > 0) BuyStop   = oBuyPrice - InitialStop*_point; else BuyStop   = 0;
               if (TakeProfit  > 0) BuyProfit = oBuyPrice + TakeProfit*_point ; else BuyProfit = 0;   
               int ticket = BuyOrdOpen(OP_BUYSTOP,oBuyPrice,BuyStop,BuyProfit,cnt);
               
               if(ticket>0){
                  buyOrders[cnt-1][0] = ticket;
                  buyOrders[cnt-1][1] = oBuyPrice;
               }
            }
            else if(ECN_Mode /* && ((!Straddle_Mode && sell == 0) || Straddle_Mode)*/)
            {
               BuyStop   = 0;
               BuyProfit = 0;
               
               if(BuyEvent == 0)
               {
                  BuyLevel[cnt-1] = BuyPrice + (PendOrdGap+OrdersStep*(cnt-1))*_point;
                  if (DisplayLevels)
                  {
                     ObjectCreate (uniqueName + " arrbl "+(string)cnt,OBJ_ARROW,0,OpenTime,BuyLevel[cnt-1]);
                     ObjectSet    (uniqueName + " arrbl "+(string)cnt,OBJPROP_ARROWCODE,1);
                     ObjectSet    (uniqueName + " arrbl "+(string)cnt,OBJPROP_COLOR,clrLightBlue);                    
                     ObjectSetText(uniqueName + " arrbl "+(string)cnt,Symbol() + " " + "Buy Level #" + (string)cnt,8);          
                  }
               
                  if(cnt == OrdersNum) BuyEvent = 1;
               } 
                              
               if(Ask >= BuyLevel[cnt-1] && pAsk < BuyLevel[cnt-1] && !VerifyComment(1,cnt) && BuyNum[cnt-1] == 0)
               { 
                  int ticket = BuyOrdOpen(OP_BUY,Ask,BuyStop,BuyProfit,cnt);
                  
                  if(ticket>0){
                      buyOrders[cnt-1][0] = ticket;
                      buyOrders[cnt-1][1] = Ask;
                   }
               }
            }
         
            if(!ECN_Mode)
		      {
               double oSellPrice = SellPrice - (PendOrdGap+OrdersStep*(cnt-1))*_point;
   		      if (InitialStop > 0) SellStop  = oSellPrice + InitialStop*_point; else SellStop=0;
               if (TakeProfit  > 0) SellProfit= oSellPrice - TakeProfit*_point ; else SellProfit=0;
               int ticket = SellOrdOpen(OP_SELLSTOP,oSellPrice,SellStop,SellProfit,cnt);
                  
               if(ticket>0){
                   sellOrders[cnt-1][0] = ticket;
                   sellOrders[cnt-1][1] = oSellPrice;
                }
            }
            else if(ECN_Mode /*&& ((!Straddle_Mode && buy == 0) || Straddle_Mode)*/)
            {
               SellStop   = 0; 
               SellProfit = 0;
               if(SellEvent == 0)
               {
                  SellLevel[cnt-1] = SellPrice - (PendOrdGap+OrdersStep*(cnt-1))*_point;
                  
                  if (DisplayLevels)
                  {         
                  ObjectCreate (uniqueName + " arrsl "+(string)cnt,OBJ_ARROW,0,OpenTime,SellLevel[cnt-1]);
                  ObjectSet    (uniqueName + " arrsl "+(string)cnt,OBJPROP_ARROWCODE,2); 
                  ObjectSet    (uniqueName + " arrsl "+(string)cnt,OBJPROP_COLOR,clrTomato);                    
                  ObjectSetText(uniqueName + " arrsl "+(string)cnt,Symbol() + " " + "Sell Level #" + (string)cnt,8);          
                  }
                  if(cnt == OrdersNum) SellEvent = 1;
               } 
               
               if(Bid <= SellLevel[cnt-1] && pBid > SellLevel[cnt-1] && !VerifyComment(2,cnt) && SellNum[cnt-1] == 0)
               { 
                  int ticket = SellOrdOpen(OP_SELL,Bid,SellStop,SellProfit,cnt);

                  if(ticket>0){
                      sellOrders[cnt-1][0] = ticket;
                      sellOrders[cnt-1][1] = Bid;
                   }
               }
            }
         }
      }
   }
   
   pBid = Bid; 
   pAsk = Ask;  
      
   return(0);
}
//+------------------------------------------------------------------+

void analizeNewsTrade(){
   double dForecast = parseDouble(NewsForecast);
   double dPrevious = parseDouble(NewsPrevious);
   if(dPrevious!=0){
   double changePercentage = (dForecast - dPrevious)/dPrevious*100;
   
   string eventName = purifyEventName(NewsName);
   Print(eventName + "; sPrevious "+ NewsPrevious+ "; sForecast "+NewsForecast+"; change, % "+changePercentage+ " => P/L: "+tradeProfitLoss);
   }
}

double parseDouble(string param){
      double result = 0;
       
		if (StringLen(param) > 0)

			if ( StringFind(param,"%",0) != -1 ) {
			   StringReplace(param,"%","");
				result = StrToDouble(param);
				result = result * 0.01;

			} else if ( StringFind(param,"K",0) != -1 ) {
				StringReplace(param,"K","");
				result = StrToDouble(param);
				result = result * 1000;

			} else if ( StringFind(param,"M",0) != -1 ) {
				StringReplace(param,"M","");
				result = StrToDouble(param);
				result = result * 1000000;

			} else if ( StringFind(param,"M",0) != -1 ) {
				StringReplace(param,"B","");
				result = StrToDouble(param);
				result = result * 1000000000;
			}

   return result;
}

string purifyEventName(string name){

   StringReplace(name," (Jan)","");
   StringReplace(name," (Feb)","");
   StringReplace(name," (Mar)","");
   StringReplace(name," (Apr)","");
   StringReplace(name," (May)","");
   StringReplace(name," (Jun)","");
   StringReplace(name," (Jul)","");
   StringReplace(name," (Aug)","");
   StringReplace(name," (Sep)","");
   StringReplace(name," (Oct)","");
   StringReplace(name," (Nov)","");
   StringReplace(name," (Dec)","");
   StringReplace(name," (Q1)","");
   StringReplace(name," (Q2)","");
   StringReplace(name," (Q3)","");
   StringReplace(name," (Q4)","");

 return name;
}

bool isSummerDaylightSaving(datetime date) {
   bool isSummer = false;
   int month = TimeMonth(date);
   int day = TimeDay(date);
   int dayOfWeek = TimeDayOfWeek(date);
   
   if(dayOfWeek == 0) dayOfWeek = 7;
   
   if(month > 3 && month < 10) isSummer = true;
   else
   if(month > 10 || month < 3) isSummer = false;
   else
   if(month == 3 && 31 - day + dayOfWeek >= 7){
      if(31 - day + dayOfWeek >= 7) isSummer = false;
      else isSummer = true;
   }
   else
   if(month == 10){
      if(31 - day + dayOfWeek < 7) isSummer = false;
      else isSummer = true;
   }
   
   return isSummer;
}

//+---------------------------------------------------------------------------------------------------------------------+
//|                                                        Events                                                       |
//+---------------------------------------------------------------------------------------------------------------------+
// массив открытых позиций состоянием на предыдущий тик previous tick moment open orders
int pre_OrdersArray[][2]; // [количество позиций][№ тикета, тип позиции]

// переменные событий
int eventBuyClosed_SL  = 0, eventBuyClosed_TP  = 0;
int eventSellClosed_SL = 0, eventSellClosed_TP = 0;
int eventBuyLimitDeleted_Exp  = 0, eventBuyStopDeleted_Exp  = 0;
int eventSellLimitDeleted_Exp = 0, eventSellStopDeleted_Exp = 0;
int eventBuyLimitOpened  = 0, eventBuyStopOpened  = 0;
int eventSellLimitOpened = 0, eventSellStopOpened = 0;

void CheckEvents( int magic = 0 )
{
	// флаг первого запуска
	static bool first = true;
	// код последней ошибки
	int _GetLastError = 0;
	// общее количество позиций
	int _OrdersTotal = OrdersTotal();
	// кол-во позиций, соответствующих критериям (текущий инструмент и заданный MagicNumber),
	// состоянием на текущий тик
	int now_OrdersTotal = 0;
	// кол-во позиций, соответствующих критериям, состоянием на предыдущий тик
	static int pre_OrdersTotal = 0;
	// массив открытых позиций состоянием на текущий тик
	int now_OrdersArray[][2]; // [№ в списке][№ тикета, тип позиции]
	// текущий номер позиции в массиве now_OrdersArray (для перебора)
	int now_CurOrder = 0;
	// текущий номер позиции в массиве pre_OrdersArray (для перебора)
	int pre_CurOrder = 0;

	// массив для хранения количества закрытых позиций каждого типа
	int now_ClosedOrdersArray[6][3]; // [тип ордера][тип закрытия]
	// массив для хранения количества сработавших отложенных ордеров
	int now_OpenedPendingOrders[4]; // [тип ордера]

	// временные флаги
	bool OrderClosed = true, PendingOrderOpened = false;
	// временные переменные
	int ticket = 0, type = -1, close_type = -1;

	//обнуляем переменные событий
	eventBuyClosed_SL  = 0; eventBuyClosed_TP  = 0;
	eventSellClosed_SL = 0; eventSellClosed_TP = 0;
	eventBuyLimitDeleted_Exp  = 0; eventBuyStopDeleted_Exp  = 0;
	eventSellLimitDeleted_Exp = 0; eventSellStopDeleted_Exp = 0;
	eventBuyLimitOpened  = 0; eventBuyStopOpened  = 0;
	eventSellLimitOpened = 0; eventSellStopOpened = 0;

	// изменяем размер массива открытых позиций под текущее кол-во
	ArrayResize( now_OrdersArray, MathMax( _OrdersTotal, 1 ) );
	// обнуляем массив
	ArrayInitialize( now_OrdersArray, 0.0 );

	// обнуляем массивы закрытых позиций и сработавших ордеров
	ArrayInitialize( now_ClosedOrdersArray, 0.0 );
	ArrayInitialize( now_OpenedPendingOrders, 0.0 );

	//+------------------------------------------------------------------+
	//| Перебираем все позиции и записываем в массив только те, которые
	//| соответствуют критериям
	//+------------------------------------------------------------------+
	for ( int z = _OrdersTotal - 1; z >= 0; z -- )
	{
		if ( !OrderSelect( z, SELECT_BY_POS ) )
		{
			_GetLastError = GetLastError();
			Print( "OrderSelect( ", z, ", SELECT_BY_POS ) - Error #", _GetLastError );
			continue;
		}
		// Считаем количество ордеров по текущему символу и с заданным MagicNumber
		if ( OrderMagicNumber() == magic && OrderSymbol() == Symbol() )
		{
			now_OrdersArray[now_OrdersTotal][0] = OrderTicket();
			now_OrdersArray[now_OrdersTotal][1] = OrderType();
			now_OrdersTotal ++;
		}
	}
	// изменяем размер массива открытых позиций под кол-во позиций, соответствующих критериям
	ArrayResize( now_OrdersArray, MathMax( now_OrdersTotal, 1 ) );

	//+------------------------------------------------------------------+
	//| Перебираем список позиций предыдущего тика, и считаем сколько закрылось позиций и
	//| сработало отложенных ордеров
	//+------------------------------------------------------------------+
	for ( pre_CurOrder = 0; pre_CurOrder < pre_OrdersTotal; pre_CurOrder ++ )
	{
		// запоминаем тикет и тип ордера
		ticket = pre_OrdersArray[pre_CurOrder][0];
		type   = pre_OrdersArray[pre_CurOrder][1];
		// предпологаем, что если это позиция, то она закрылась
		OrderClosed = true;
		// предполагаем, что если это был отложенный ордер, то он не сработал
		PendingOrderOpened = false;

		// перебираем все позиции из текущего списка открытых позиций
		for ( now_CurOrder = 0; now_CurOrder < now_OrdersTotal; now_CurOrder ++ )
		{
			// если позиция с таким тикетом есть в списке,
			if ( ticket == now_OrdersArray[now_CurOrder][0] )
			{
				// значит позиция не была закрыта (ордер не был удалён)
				OrderClosed = false;

				// если её тип поменялся,
				if ( type != now_OrdersArray[now_CurOrder][1] )
				{
					// значит это был отложенный ордер, и он сработал
					PendingOrderOpened = true;
				   openPriceImprovement(ticket);
				}
				break;
			}
		}
		// если была закрыта позиция (удалён ордер),
		if ( OrderClosed )
		{
			// выбираем её
			if ( !OrderSelect( ticket, SELECT_BY_TICKET ) )
			{
				_GetLastError = GetLastError();
				Print( "OrderSelect( ", ticket, ", SELECT_BY_TICKET ) - Error #", _GetLastError );
				continue;
			}
			// и определяем, КАК закрылась позиция (удалился ордер):
			if ( type < 2 )
			{
				// Buy & Sell: 0 - manual, 1 - SL, 2 - TP
				close_type = 0;
				if ( StringFind( OrderComment(), "[sl]" ) >= 0 ) close_type = 1;
				if ( StringFind( OrderComment(), "[tp]" ) >= 0 ) close_type = 2;
				
            calcAccountChange();
				slipImprovements(ticket);
			}
			else
			{
				// Отложенные ордера: 0 - вручную, 1 - время истечения
				close_type = 0;
				if ( StringFind( OrderComment(), "expiration" ) >= 0 ) close_type = 1;
				
			}
			
			// и записываем в массив закрытых ордеров, что ордер с типом type 
			// закрылся при обстоятельствах close_type
			now_ClosedOrdersArray[type][close_type] ++;
			continue;
		}
		// если сработал отложенный ордер,
		if ( PendingOrderOpened )
		{  
			// записываем в массив сработавших ордеров, что ордер с типом type сработал
			now_OpenedPendingOrders[type-2] ++;
			continue;
		}
	}

	//+------------------------------------------------------------------+
	//| Всю необходимую информацию собрали - назначаем переменным событий нужные значения
	//+------------------------------------------------------------------+
	// если это не первый тик после запуска эксперта
	if ( !first )
	{
		// перебираем все элементы массива срабатывания отложенных ордеров
		for ( type = 2; type < 6; type ++ )
		{
			// и если элемент не пустой (ордер такого типа сработал), меняем значение переменной
			if ( now_OpenedPendingOrders[type-2] > 0 )
				SetOpenEvent( type );
		}

		// перебираем все элементы массива закрытых позиций
		for ( type = 0; type < 6; type ++ )
		{
			for ( close_type = 0; close_type < 3; close_type ++ )
			{
				// и если элемент не пустой (была закрыта позиция), меняем значение переменной
				if ( now_ClosedOrdersArray[type][close_type] > 0 )
					SetCloseEvent( type, close_type );
			}
		}
	}
	else
	{
		first = false;
	}

	//---- сохраняем массив текущих позиций в массив предыдущих позиций
	ArrayResize( pre_OrdersArray, MathMax( now_OrdersTotal, 1 ) );
	for ( now_CurOrder = 0; now_CurOrder < now_OrdersTotal; now_CurOrder ++ )
	{
		pre_OrdersArray[now_CurOrder][0] = now_OrdersArray[now_CurOrder][0];
		pre_OrdersArray[now_CurOrder][1] = now_OrdersArray[now_CurOrder][1];
	}
	pre_OrdersTotal = now_OrdersTotal;
}


void calcAccountChange(){
   changePL = (AccountEquity() - depositTotal)/depositTotal*100;
   changeAfterLastEvent = (AccountEquity() - equityBeforeEvent)/equityBeforeEvent*100;
}


//+----------------------------------------------------------------------------------+
//|                                                                                  |
//|                                 TP/SL slippage analisys                          |
//|                                                                                  |
//+----------------------------------------------------------------------------------+
void slipImprovements(int ticket){

   if(!OrderSelect(ticket, SELECT_BY_TICKET)){
      Print( "OrderSelect( ", ticket, ", SELECT_BY_TICKET ) - Error #", GetLastError() ); return;
   }

   double slipImprovement = 0.0;
   double closePrice = OrderClosePrice();
   double tp = OrderTakeProfit();
   double sl = OrderStopLoss();
   
   double closeByTPFactor = NormalizeDouble(MathAbs(closePrice - tp), Digits);
   double closeBySLFactor = NormalizeDouble(MathAbs(closePrice - sl), Digits);
  
  
  if(closeByTPFactor < closeBySLFactor){
      //assume close by TP
      if(OrderType() == OP_BUY)
         slipImprovement = NormalizeDouble(closePrice - tp, Digits);
      else if (OrderType() == OP_SELL)
         slipImprovement = NormalizeDouble(tp - closePrice, Digits);

      slipImprovement = NormalizeDouble(slipImprovement * MathPow(10, (Digits-1)), 2);
      
      tpCounter++;
      tpSum += slipImprovement;
      avgTPImprovement = NormalizeDouble(tpSum/tpCounter,1);
      
      if(slipImprovement > maxTPImprovement){
         maxTPImprovement = slipImprovement;
         maxTPImprovmentTicket = ticket;
      }
      
      if(slipImprovement < minTPImprovement){
         minTPImprovement = slipImprovement;
         minTPImprovmentTicket = ticket;
      }
      
      string txt;
      
      if(slipImprovement >=0 ){
         tpBetterCounter++;
         tpImprovedPerc = NormalizeDouble(tpBetterCounter/tpCounter*100, 2);
         txt = "Ticket #" + OrderTicket() + " TP " + (slipImprovement>0 ? "improved, pips: " + slipImprovement: " was accurate");
         if(PrintInLog) Print(txt);
      }
      else{
         txt = "Ticket #" + OrderTicket() + " TP slipped, pips: " + slipImprovement;
         if(PrintInLog) Print(txt);
         }
         
      if(DetailedStatsEmail) emailDetailedStats += txt + "<br/>\n";
  }
  else{//assume closed by SL
      if(OrderType() == OP_BUY)
         slipImprovement = NormalizeDouble(closePrice - sl, Digits);
      else if (OrderType() == OP_SELL)
         slipImprovement = NormalizeDouble(sl - closePrice, Digits);
         
      slipImprovement = NormalizeDouble(slipImprovement * MathPow(10, (Digits-1)), 2);
      
      slCounter++;
      slSum += slipImprovement;
      avgSLImprovement = NormalizeDouble(slSum/slCounter,1);
      
      if(slipImprovement > maxSLImprovement){
         maxSLImprovement = slipImprovement;
         maxSLImprovmentTicket = ticket;
      }
      
      if(slipImprovement < minSLImprovement){
         minSLImprovement = slipImprovement;
         minSLImprovmentTicket = ticket;
      }
      
      string txt;
      
      if(slipImprovement >=0 ){
         slBetterCounter++;
         slImprovedPerc = NormalizeDouble(slBetterCounter/slCounter*100, 2);
         txt = "Ticket #" + OrderTicket() + " SL " + (slipImprovement>0 ? "improved, pips: " + slipImprovement: " was accurate");
         if(PrintInLog) Print(txt);
      }
      else{
         txt = "Ticket #" + OrderTicket() + " SL slipped, pips: " + slipImprovement;
         if(PrintInLog) Print(txt);
         }
         
      if(DetailedStatsEmail) emailDetailedStats += txt + "<br/>\n";
  }
}

/************************************************************************************
/
/      Open price improvements (positive value) or slippage - negative values 
/
************************************************************************************/
void openPriceImprovement(int ticket){

   double priceImprovement = 0.0;
   bool flag;

   for(int i=0; i<OrdersNum; i++){
      int buyTicket = (int)buyOrders[i][0];
      int sellTicket = (int)sellOrders[i][0];
      
      if(buyTicket == 0 && sellTicket == 0) continue;
      
      if(buyTicket == ticket){
         if(OrderSelect(ticket, SELECT_BY_TICKET)){
            double givenPrice = OrderOpenPrice();
            double requestedPrice = buyOrders[i][1];
            priceImprovement =  NormalizeDouble(requestedPrice - givenPrice, Digits);
            flag = true;
            
         }
         else{
				Print( "OrderSelect( ", ticket, ", SELECT_BY_TICKET ) - Error #", GetLastError() );
			}
			break;
      }
      
      if(sellTicket == ticket){
         if(OrderSelect(ticket, SELECT_BY_TICKET)){
            double givenPrice = OrderOpenPrice();
            double requestedPrice = sellOrders[i][1];
            priceImprovement = NormalizeDouble(givenPrice - requestedPrice, Digits);
            flag = true;
            
         }
         else{
				Print( "OrderSelect( ", ticket, ", SELECT_BY_TICKET ) - Error #", GetLastError() );
			}
			break;
      }
   }
   
   if(flag == true){
      priceImprovement = NormalizeDouble(priceImprovement * MathPow(10, (Digits-1)), 2);
      calcOpenPriceImprovements(ticket, priceImprovement);
      
      if(DetailedStatsEmail){
         if(priceImprovement!=0)
          emailDetailedStats += "Order #" + ticket + " open price improved/slipped, pips: " + priceImprovement + "<br/>\n";
         else
          emailDetailedStats += "Order #" + ticket + " open price was accurate" + "<br/>\n";
      }
   }
}

void calcOpenPriceImprovements(int ticket, double priceImprovement){
   priceImpCounter ++;
   priceImpSum += priceImprovement;
   
   if(priceImprovement >=0 ){
      priceBetterCounter++;
      openPriceImprovedPerc = NormalizeDouble(priceBetterCounter/priceImpCounter*100, 2);
   }
   
   avgOpenPriceImprovement = NormalizeDouble(priceImpSum/priceImpCounter, 1);
   
   if(priceImprovement < minOpenPriceImprovement){
      minOpenPriceImprovmentTicket = ticket;
      minOpenPriceImprovement = priceImprovement;
   }
   
   if( priceImprovement > maxOpenPriceImprovement ){
      maxOpenPriceImprovmentTicket = ticket;
      maxOpenPriceImprovement = priceImprovement;
   }
}

void SetOpenEvent( int SetOpenEvent_type )
{
	switch ( SetOpenEvent_type )
	{
		case OP_BUYLIMIT: eventBuyLimitOpened ++;
		case OP_BUYSTOP: eventBuyStopOpened ++;
		case OP_SELLLIMIT: eventSellLimitOpened ++;
		case OP_SELLSTOP: eventSellStopOpened ++;
	}
}
void SetCloseEvent( int SetCloseEvent_type, int SetCloseEvent_close_type )
{
	switch ( SetCloseEvent_type )
	{
		case OP_BUY:
		{
			if ( SetCloseEvent_close_type == 1 ) eventBuyClosed_SL ++;
			if ( SetCloseEvent_close_type == 2 ) eventBuyClosed_TP ++;
		}
		case OP_SELL:
		{
			if ( SetCloseEvent_close_type == 1 ) eventSellClosed_SL ++;
			if ( SetCloseEvent_close_type == 2 ) eventSellClosed_TP ++;
		}
		case OP_BUYLIMIT:
		{
			if ( SetCloseEvent_close_type == 1 ) eventBuyLimitDeleted_Exp ++;
		}
		case OP_BUYSTOP:
		{
			if ( SetCloseEvent_close_type == 1 ) eventBuyStopDeleted_Exp ++;
		}
		case OP_SELLLIMIT:
		{
			if ( SetCloseEvent_close_type == 1 ) eventSellLimitDeleted_Exp ++;
		}
		case OP_SELLSTOP:
		{
			if ( SetCloseEvent_close_type == 1 ) eventSellStopDeleted_Exp ++;
		}
	}
}


void sendEmailNotification(){
   if (NotifyByEmail) {
   
   string eventInfo = currEventInfo;
   StringReplace(eventInfo,"\n\n","<br/>");

string MailHTMLBody = "<html>"
"<head>\n"
        "<title></title>\n"
"</head>\n"
"<body>\n"
"<h3>Account report on economic news release trading:</h3>\n"
"<br/>\n"
"<br/>\n"
"<div>" + eventInfo + "</div>\n"
"<br/>\n"
"<br/>\n"

"<table align=\"left\" border=\"1\" cellpadding=\"1\" cellspacing=\"1\" style=\"width: 500px;\">\n"
        "<thead>\n"
                "<tr>\n"
                        "<th scope=\"col\">Name</th>\n"
                        "<th scope=\"col\">Value</th>\n"
                "</tr>\n"
        "</thead>\n"
        "<tbody>\n";

                //price opening improvements
                if(priceImpCounter>0)
                   MailHTMLBody +=
                    "<tr>\n"
                           "<td style=\"text-align: center;\" colspan=\"2\">Price Improvement (+) or Slippage (-)</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Min</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(minOpenPriceImprovement,1)+" Pips" + "  ticket #" + minOpenPriceImprovmentTicket +"</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Max</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(maxOpenPriceImprovement,1)+" Pips" + "  ticket #" + maxOpenPriceImprovmentTicket +"</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Avg</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(avgOpenPriceImprovement,1)+" Pips</td>\n"
                   "</tr>\n";
                   
                //TP improvements
                if(tpCounter>0)
                   MailHTMLBody +=
                    "<tr>\n"
                           "<td style=\"text-align: center;\" colspan=\"2\">TP Improvement (+) or Slippage (-)</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Min</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(minTPImprovement,1)+" Pips</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Max</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(maxTPImprovement,1)+" Pips</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Avg</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(avgTPImprovement,1)+" Pips</td>\n"
                   "</tr>\n";
                   
                //SL improvements
                if(slCounter>0)
                   MailHTMLBody +=
                    "<tr>\n"
                           "<td style=\"text-align: center;\" colspan=\"2\">SL Improvement (+) or Slippage (-)</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Min</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(minSLImprovement,1)+" Pips</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Max</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(maxSLImprovement,1)+" Pips</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Avg</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(avgSLImprovement,1)+" Pips</td>\n"
                   "</tr>\n";
                   
                //Spread stats
                if(spreadCnt>0)
                   MailHTMLBody +=
                    "<tr>\n"
                           "<td style=\"text-align: center;\" colspan=\"2\">Spread during Last News</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Min</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(minSpreadLE,1)+" Pips</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Max</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(maxSpreadLE,1)+" Pips</td>\n"
                   "</tr>\n"
                   "<tr>\n"
                           "<td style=\"text-align: center;\">Avg</td>\n"
                           "<td style=\"text-align: center;\">"+DoubleToString(avgSpreadLE,1)+" Pips</td>\n"
                   "</tr>\n";
                
                // Account change, margin level
                MailHTMLBody +=
                "<tr>\n"
                           "<td style=\"text-align: center;\" colspan=\"2\">Account Change Info</td>\n"
                "</tr>\n"
                "<tr>\n"
                        "<td style=\"text-align: center;\">Account Change</td>\n"
                        "<td style=\"text-align: center;\">" + DoubleToString(changePL,2) + " %" + "</td>\n"
                "</tr>\n"
                "<tr>\n"
                        "<td style=\"text-align: center;\">After Last Event</td>\n"
                        "<td style=\"text-align: center;\">" + DoubleToString( changeAfterLastEvent,2) + " %" + "</td>\n"
                "</tr>\n"
                "<tr>\n"
                        "<td style=\"text-align: center;\">Min. Margin Level</td>\n"
                        "<td style=\"text-align: center;\">" + DoubleToString(minMarginLevel,2) + " %"  + "</td>\n"
                "</tr>\n"
                "<tr>\n"
                        "<td style=\"text-align: center;\" colspan=\"2\">Account Information</td>\n"
                "</tr>\n"          
                "<tr>\n"
                        "<td style=\"text-align: center;\">AccountNumber</td>\n"
                        "<td style=\"text-align: center;\">" + IntegerToString(AccountNumber()) + "</td>\n"
                "</tr>\n"
                "<tr>\n"
                        "<td style=\"text-align: center;\">AccountCompany</td>\n"
                        "<td style=\"text-align: center;\">" + AccountCompany() + "</td>\n"
                "</tr>\n"
                "<tr>\n"
                        "<td style=\"text-align: center;\">AccountServer</td>\n"
                        "<td style=\"text-align: center;\">" + AccountServer() + "</td>\n"
                "</tr>\n"
                "<tr>\n"
                        "<td style=\"text-align: center;\">AccountLeverage</td>\n"
                        "<td style=\"text-align: center;\">" + AccountLeverage() + "</td>\n"
                "</tr>\n"
        "</tbody>\n"
"</table>\n";

               if(StringCompare(emailDetailedStats,"")!=0)
                  MailHTMLBody += emailDetailedStats;
               
               //end of the HTML body              
               MailHTMLBody +=
"</body>\n"
"</html>";
      
      SendMail( ExpertName + " Notification", MailHTMLBody);
      Print("Email notification has been puted into the send queue...");
   }
}

void readProperties()
{   
	string pName = ExpertName + ".properties";
	
	if(!FileIsExist(pName)){
   	   if(PrintInLog) Print("File " + pName + " does not exists ", GetLastError());
   	   return;
	}
	
	int handle = FileOpen(pName,FILE_TXT|FILE_READ);

	if(handle == INVALID_HANDLE)
	{
	   Print("File " + pName + " open error ", GetLastError());
	}
	else
	{
      Print("Reading properties from: " + pName);
      int i = 0;
      int line=0;
      
      while(!FileIsEnding(handle))
      {   
          string line = FileReadString(handle);
          int p = StringFind(line,"=",0);
          if(p>0){
            string name = StringSubstr(line,0,p);
            string value = StringSubstr(line,p+1,StringLen(line));
            
            //+------------------------------------------------------------------+
            //|   Open price improvement assessment variables                    |
            //+------------------------------------------------------------------+
            if(name=="maxOpenPriceImprovmentTicket"){
              maxOpenPriceImprovmentTicket = StringToInteger(value);
              //Print("name: " + name + "=" + maxOpenPriceImprovmentTicket);
            }else if(name=="minOpenPriceImprovmentTicket"){
              minOpenPriceImprovmentTicket = StringToInteger(value);
              //Print("name: " + name + "=" + minOpenPriceImprovmentTicket);
            }if(name=="maxTPImprovmentTicket"){
              maxTPImprovmentTicket = StringToInteger(value);
              //Print("name: " + name + "=" + maxTPImprovmentTicket);
            }else if(name=="minTPImprovmentTicket"){
              minTPImprovmentTicket = StringToInteger(value);
              //Print("name: " + name + "=" + minTPImprovmentTicket);
            }if(name=="maxSLImprovmentTicket"){
              maxSLImprovmentTicket = StringToInteger(value);
              //Print("name: " + name + "=" + maxSLImprovmentTicket);
            }else if(name=="minSLImprovmentTicket"){
              minSLImprovmentTicket = StringToInteger(value);
              //Print("name: " + name + "=" + minSLImprovmentTicket);
            }else if(name=="maxOpenPriceImprovement"){
              maxOpenPriceImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + maxOpenPriceImprovement);
            }else if(name=="minOpenPriceImprovement"){
              minOpenPriceImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + minOpenPriceImprovement);
            }else if(name=="avgOpenPriceImprovement"){
              avgOpenPriceImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + avgOpenPriceImprovement);
            }else if(name=="openPriceImprovedPerc"){
              openPriceImprovedPerc = StringToDouble(value);
              //Print("name: " + name + "=" + openPriceImprovedPerc);
            }else if(name=="priceBetterCounter"){
              priceBetterCounter = StringToDouble(value);
              //Print("name: " + name + "=" + priceBetterCounter);
            }else if(name=="priceImpCounter"){
              priceImpCounter = StringToInteger(value);
              //Print("name: " + name + "=" + priceImpCounter);
            }else if(name=="priceImpSum"){
              priceImpSum = StringToDouble(value);
              //Print("name: " + name + "=" + priceImpSum);
            }
            //+------------------------------------------------------------------+
            //|   Take Profit price improvement assessment variables             |
            //+------------------------------------------------------------------+
            else if(name=="maxTPImprovement"){
              maxTPImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + maxTPImprovement);
            }else if(name=="minTPImprovement"){
              minTPImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + minTPImprovement);
            }else if(name=="avgTPImprovement"){
              avgTPImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + avgTPImprovement);
            }else if(name=="tpImprovedPerc"){
              tpImprovedPerc = StringToDouble(value);
              //Print("name: " + name + "=" + tpImprovedPerc);
            }else if(name=="tpBetterCounter"){
              tpBetterCounter = StringToInteger(value);
              //Print("name: " + name + "=" + tpBetterCounter);
            }else if(name=="tpCounter"){
              tpCounter = StringToInteger(value);
              //Print("name: " + name + "=" + tpCounter);
            }else if(name=="tpSum"){
              tpSum = StringToDouble(value);
              //Print("name: " + name + "=" + tpSum);
            }
            //+------------------------------------------------------------------+
            //|   Stop Loss price improvement assessment variables               |
            //+------------------------------------------------------------------+
            else if(name=="maxSLImprovement"){
              maxSLImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + maxSLImprovement);
            }else if(name=="minSLImprovement"){
              minSLImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + minSLImprovement);
            }else if(name=="avgSLImprovement"){
              avgSLImprovement = StringToDouble(value);
              //Print("name: " + name + "=" + avgSLImprovement);
            }else if(name=="slImprovedPerc"){
              slImprovedPerc = StringToDouble(value);
              //Print("name: " + name + "=" + slImprovedPerc);
            }else if(name=="slBetterCounter"){
              slBetterCounter = StringToInteger(value);
              //Print("name: " + name + "=" + slBetterCounter);
            }else if(name=="slCounter"){
              slCounter = StringToInteger(value);
              //Print("name: " + name + "=" + slCounter);
            }else if(name=="slSum"){
              slSum = StringToDouble(value);
              //Print("name: " + name + "=" + slSum);
            }
            //+------------------------------------------------------------------+
            //|             account statistics                                   |
            //+------------------------------------------------------------------+
            else if(name=="minMarginLevel"){
              minMarginLevel = StringToDouble(value);
              //Print("name: " + name + "=" + minMarginLevel);
            }else if(name=="changeAfterLastEvent"){
              changeAfterLastEvent = StringToDouble(value);
              //Print("name: " + name + "=" + changeAfterLastEvent);
            }else if(name=="equityBeforeEvent"){
              equityBeforeEvent = StringToDouble(value);
              //Print("name: " + name + "=" + equityBeforeEvent);
            }else if(name=="depositTotal"){
              depositTotal = StringToDouble(value);
              //Print("name: " + name + "=" + depositTotal);
            }else if(name=="changePL"){
              changePL = StringToDouble(value);
              //Print("name: " + name + "=" + changePL);
            }
            //+------------------------------------------------------------------+
            //|             Spread statistics                                    |
            //+------------------------------------------------------------------+
            else if(name=="minSpread"){
              minSpread = StringToDouble(value);
              //Print("name: " + name + "=" + minSpread);
            }else if(name=="maxSpread"){
              maxSpread = StringToDouble(value);
              //Print("name: " + name + "=" + maxSpread);
            }else if(name=="avgSpread"){
              avgSpread = StringToDouble(value);
              //Print("name: " + name + "=" + avgSpread);
            }else if(name=="spreadSum"){
              spreadSum = StringToDouble(value);
              //Print("name: " + name + "=" + spreadSum);
            }else if(name=="spreadCnt"){
              spreadCnt = StringToInteger(value);
              //Print("name: " + name + "=" + spreadCnt);
            }else if(name=="minSpreadLE"){
              minSpreadLE = StringToDouble(value);
              //Print("name: " + name + "=" + minSpreadLE);
            }else if(name=="maxSpreadLE"){
              maxSpreadLE = StringToDouble(value);
              //Print("name: " + name + "=" + maxSpreadLE);
            }else if(name=="avgSpreadLE"){
              avgSpreadLE = StringToDouble(value);
              //Print("name: " + name + "=" + avgSpreadLE);
            }else if(name=="spreadSumLE"){
              spreadSumLE = StringToDouble(value);
              //Print("name: " + name + "=" + spreadSumLE);
            }else if(name=="spreadCntLE"){
              spreadCntLE = StringToInteger(value);
              //Print("name: " + name + "=" + spreadCntLE);
            }
          }
      }
      
      FileClose(handle);
	}
}


void writeProperties()
{
	string pName = ExpertName + ".properties";

	Print("Writing properties to file: " + pName);
	
	if(FileIsExist(pName)){
	   if(!FileDelete(pName)){
	      Print("Error: Unable to delete file " + pName , GetLastError());
	   }else{
	       Print("Old file " + pName + " has been deleted.");
	   }
	}
	
	int handle = FileOpen(pName,FILE_TXT|FILE_WRITE);

	if(handle == INVALID_HANDLE)
	{
	   Print("File " + pName + " open error ", GetLastError());
	}
	else
	{  string NL = "\n";
      string line = "maxOpenPriceImprovmentTicket="+maxOpenPriceImprovmentTicket+NL;
      line+= "minOpenPriceImprovmentTicket="+minOpenPriceImprovmentTicket+NL;
      line+= "maxTPImprovmentTicket="+maxTPImprovmentTicket+NL;
      line+= "minTPImprovmentTicket="+minTPImprovmentTicket+NL;
      line+= "maxSLImprovmentTicket="+maxSLImprovmentTicket+NL;
      line+= "minSLImprovmentTicket="+minSLImprovmentTicket+NL;
      line+= "maxOpenPriceImprovement="+maxOpenPriceImprovement+NL;
      line+= "minOpenPriceImprovement="+minOpenPriceImprovement+NL;
      line+= "avgOpenPriceImprovement="+avgOpenPriceImprovement+NL;
      line+= "openPriceImprovedPerc="+openPriceImprovedPerc+NL;
      line+= "priceBetterCounter="+priceBetterCounter+NL;
      line+= "priceBetterCounter="+priceBetterCounter+NL;
      line+= "priceImpCounter="+priceImpCounter+NL;
      line+= "priceImpSum="+priceImpSum+NL;

      //+------------------------------------------------------------------+
      //|   Take Profit price improvement assessment variables             |
      //+------------------------------------------------------------------+
      line+= "maxTPImprovement="+maxTPImprovement+NL;
      line+= "minTPImprovement="+minTPImprovement+NL;
      line+= "avgTPImprovement="+avgTPImprovement+NL;
      line+= "tpImprovedPerc="+tpImprovedPerc+NL;
      line+= "tpBetterCounter="+tpBetterCounter+NL;
      line+= "tpCounter="+tpCounter+NL;
      line+= "tpCounter="+tpCounter+NL;
      line+= "tpSum="+tpSum+NL;

      //+------------------------------------------------------------------+
      //|   Stop Loss price improvement assessment variables               |
      //+------------------------------------------------------------------+
      line+= "maxSLImprovement="+maxSLImprovement+NL;
      line+= "minSLImprovement="+minSLImprovement+NL;
      line+= "avgSLImprovement="+avgSLImprovement+NL;
      line+= "slImprovedPerc="+slImprovedPerc+NL;
      line+= "slBetterCounter="+slBetterCounter+NL;
      line+= "slCounter="+slCounter+NL;
      line+= "slSum="+slSum+NL;
      //+------------------------------------------------------------------+
      //|             account statistics                                   |
      //+------------------------------------------------------------------+
      line+= "minMarginLevel="+minMarginLevel+NL;
      line+= "changeAfterLastEvent="+changeAfterLastEvent+NL;
      line+= "equityBeforeEvent="+equityBeforeEvent+NL;
      line+= "depositTotal="+depositTotal+NL;
      line+= "changePL="+changePL+NL;
      //+------------------------------------------------------------------+
      //|             Spread statistics                                   |
      //+------------------------------------------------------------------+
      line+= "minSpread="+minSpread+NL;
      line+= "maxSpread="+maxSpread+NL;
      line+= "avgSpread="+avgSpread+NL;
      line+= "spreadSum="+spreadSum+NL;
      line+= "spreadCnt="+spreadCnt+NL;
      
      line+= "minSpreadLE="+minSpreadLE+NL;
      line+= "maxSpreadLE="+maxSpreadLE+NL;
      line+= "avgSpreadLE="+avgSpreadLE+NL;
      line+= "spreadSumLE="+spreadSumLE+NL;
      line+= "spreadCntLE="+spreadCntLE+NL;
      
      FileWriteString(handle,line);

      FileClose(handle);
      Print("Properties file " + pName + " was  successfully created");
	}
}


void writeEventInfo(){
   string fileName = currEventInfo;
   fileName = StringSubstr(fileName,0,StringFind(fileName,"\n\n",0));
   StringReplace(fileName, ":", ".");
   
   string eventInfo = currEventInfo;
   StringReplace(eventInfo,"\n\n","\n");
   
   
   fileName = StringTrimRight(fileName);
   string pName = fileName + ".txt";
   
   string line = ChartComment();
   StringReplace(line, "\n\n", "\n");
   line = eventInfo + "\n" + line;
   
   if(StringCompare(emailDetailedStats,"")!=0){
      StringReplace(emailDetailedStats,"<br/>","");
      line +="\n\n" + emailDetailedStats;
   }

	Print("Writing last event info to file: " + pName);
	
	if(FileIsExist(pName)){
	   if(!FileDelete(pName)){
	      Print("Error: Unable to delete file " + pName , GetLastError());
	   }else{
	       Print("Old file " + pName + " has been deleted.");
	   }
	}
	
	int handle = FileOpen(pName,FILE_TXT|FILE_WRITE);

	if(handle == INVALID_HANDLE)
	{
	   Print("File " + pName + " open error ", GetLastError());
	}
	else
	{  
      FileWriteString(handle,line);

      FileClose(handle);
      Print("Event info file " + pName + " was  successfully created");
	}
}