//+------------------------------------------------------------------+
//|                                                   Turtles EA.mq4 |
//|                               Copyright © 2016, forexfactory.com |
//|                                                 forexfactory.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2016"
#property link      "forexfactory.com"

extern double LOT=0.01;
 double TradeRisk=0.01;
 string max_allowed_drawdown = "Maximum allowed drawdown from Initial Deporit,%";
 double MaxDrawdown=5.0;
extern int MagicNumber=12345;
extern color LabelColor=White;
extern int LabelFontSize=8;
extern color S1LongEntryLineColor=Blue;
extern color S2LongEntryLineColor=LightBlue;
extern color S1andS2LongEntryLineColor=Lime;
extern color S1ExitLinesColor=Yellow;
extern color S1ShortEntryLineColor=Red;
extern color S2ShortEntryLineColor=Pink;
extern color S1andS2ShortEntryLineColor=Orange;


int MaxCommentsToShow=25;
string allcomments[];
datetime lastcheck;
bool periodOK=false;

int S1Periods=20;
int S2Periods=55;
double S1LongEntry=0;
double S1ShortEntry=0;
double S2LongEntry=0;
double S2ShortEntry=0;

double S1LongExit=0;
double S1ShortExit=0;
double S2LongExit=0;
double S2ShortExit=0;

int S1LongEntryBar=0;
int S1ShortEntryBar=0;
int S2LongEntryBar=0;
int S2ShortEntryBar=0;

int S1LongExitBar=0;
int S1ShortExitBar=0;

double HighPriceArray[];
double LowPriceArray[];

double CurrentATR;
double UnitSizing;
int ATRStopLossMultiplier=2;
double initialDeposit=AccountEquity();

//TrendEye variables
   int li_0;
   int li_4;
   int li_8;
   int li_12;
   int li_16;
   int li_20;
   int l_highest_24;
   int l_datetime_28;
   int l_shift_32;
   int l_highest_36;
   double l_ihigh_40;
   int l_datetime_48;
   int l_day_of_week_52;
   int l_day_56;
   int l_lowest_60;
   int l_datetime_64;
   int l_shift_68;
   int l_lowest_72;
   double l_ilow_76;
   int l_datetime_84;
   int l_day_of_week_88;
   int l_day_92;
   int l_highest_96;
   int l_datetime_100;
   int l_shift_104;
   int l_highest_108;
   double l_ihigh_112;
   int l_datetime_120;
   int l_month_124;
   int l_day_128;
   int l_lowest_132;
   int l_datetime_136;
   int l_shift_140;
   int l_lowest_144;
   double l_ilow_148;
   int l_datetime_156;
   int l_month_160;
   int l_day_164;
   int l_highest_168;
   int l_datetime_172;
   int l_shift_176;
   int l_highest_180;
   double l_ihigh_184;
   int l_datetime_192;
   int l_month_196;
   int l_day_200;
   int l_lowest_204;
   int l_datetime_208;
   int l_shift_212;
   int l_lowest_216;
   double l_ilow_220;
   int l_datetime_228;
   int l_month_232;
   int l_day_236;
   double l_ima_240;
   double l_ima_248;
   double l_iclose_256;
   int li_264;
   int li_268;
   int li_272;
   int li_276;
   int li_280;
   double ld_284;
   double ld_292;
   double ld_300;
   string ls_308;
   string ls_316;
   int li_324;
   int li_328;
   int li_332;
   int gi_376 = 3;
   string gs_408;
   string gs_416;
   int g_day_516;
   int g_day_520;
   string gs_432;
   string gs_440;
   string gs_524;
   string gs_532;
   string gs_540;
   string gs_548;
   string gs_556;
   string gs_564;
   string gs_572;
   string gs_424;
   int gi_380 = 3;
   int gi_384 = 3;
   string gs_508;
   string gs_464;
   string gs_456;
   string gs_472;
   string gs_480;
   string gs_488;
   string gs_496;
   string ls_336;
   int g_day_504;
   int g_period_388 = 20;
   int g_period_392 = 5;
   int g_color_396 = CadetBlue;
   int g_color_400 = Silver;
   int g_color_404 = DimGray;
   extern int X_box = 0;
   extern int Y_box = 0;
   //TrendEye variables end

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
   
   manageupperstatus("Turtles EA - forexfactory.com, © 2016");
   if(Period()>=60)
      {
      periodOK=true;
      managelowerstatus("http://www.forexfactory.com");
      managecomments("Turtle EA Running");
      CalcTurtleValues();     
      drawentries(S1LongEntry, S2LongEntry, S1ShortEntry, S2ShortEntry, S1LongExit, S1ShortExit);
      }
   else
      {
      periodOK=false;
      managelowerstatus("ERROR: This scanner must be used on an H1 chart at least");
      managecomments("MUST USE H1 TIMEFRAME OR ABOVE - WILL NOT TRADE!!");
      deinit();
      }

   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
  return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
  if(periodOK==false) return(0);
  //Check for a new bar
  if(lastcheck<Time[0])
   {
   //A new bar has formed and new values need to be computed
   string checktime=TimeToStr(TimeLocal(),TIME_DATE);   
   lastcheck=Time[0];
   CalcTurtleValues();     
   drawentries(S1LongEntry, S2LongEntry, S1ShortEntry, S2ShortEntry, S1LongExit, S1ShortExit);
   managecomments(checktime +": New values calculated");
   }
   
   //managecomments(MarketInfo(Symbol(),MODE_TICKVALUE));
      
   //Always do the trade management functions
   //Check for orders to close
   //Close positions based on the 10-day number
   if(Bid<S1LongExit)
      {
      //Close long positions
      CloseS1LongPositions();
      ClosePendingLongPositions();
      }
      
   if(Ask>S1ShortExit)
      {
      //Close short positions
      CloseS1ShortPositions();
      ClosePendingShortPositions();
      }

   //Check for S2 long entry
   if((S2LongEntry<Ask)&&(CountLongPositions()==0))
      {
      //Need new long positions
      CurrentATR=iATR(Symbol(),PERIOD_H1,S1Periods,1);
      UnitSizing=calculateLot();
      UnitSizing=NormalizeDouble(UnitSizing,2);
      managecomments("UnitSizing="+UnitSizing);
      //Close the short positions
      CloseS1ShortPositions();
      CloseS2ShortPositions();
      ClosePendingShortPositions();
      ClosePendingLongPositions();
      //Need a new long position
      OpenS2LongPositions();
      }

   //Check for S1 long entry
   if((S1LongEntry<Ask)&&(CountLongPositions()==0))
      {
      //Need new long positions
      CurrentATR=iATR(Symbol(),PERIOD_H1,S1Periods,1);
      UnitSizing=calculateLot();
      UnitSizing=NormalizeDouble(UnitSizing,2);
      managecomments("UnitSizing="+UnitSizing);
      //Close the short positions
      CloseS1ShortPositions();
      CloseS2ShortPositions();
      ClosePendingShortPositions();
      ClosePendingLongPositions();
      //Need a new long position
      OpenS1LongPositions();
      }
   
   //Check for S2 short entry
   if((S2ShortEntry>Bid)&&(CountShortPositions()==0))
      {
      //Need new short positions
      CurrentATR=iATR(Symbol(),PERIOD_H1,S1Periods,1);
      UnitSizing=calculateLot();
      UnitSizing=NormalizeDouble(UnitSizing,2);
      managecomments("UnitSizing="+UnitSizing);
      //Close the long positions
      CloseS1LongPositions();
      CloseS2LongPositions();
      ClosePendingLongPositions();
      ClosePendingShortPositions();
      //Need a new short position
      OpenS2ShortPositions();
      } 

   //Check for S1 short entry
   if((S1ShortEntry>Bid)&&(CountShortPositions()==0))
      {
      //Need new short positions
      CurrentATR=iATR(Symbol(),PERIOD_H1,S1Periods,1);
      UnitSizing=calculateLot();
      UnitSizing=NormalizeDouble(UnitSizing,2);
      managecomments("UnitSizing="+UnitSizing);
      //Close the long positions
      CloseS1LongPositions();
      CloseS2LongPositions();
      ClosePendingLongPositions();
      ClosePendingShortPositions();
      //Need a new short position
      OpenS1ShortPositions();
      }
   
   if(OrdersTotal()>0)
      {      
      //Standardize the stops
      StandardStopsForShorts();
      StandardStopsForLongs();
      }
   return(0);
  }
//+------------------------------------------------------------------+

void CalcTurtleValues()
   {
   trendEye();
   //Prepare and fill the two arrays 
   int pricecounter=0;
   ArrayResize(HighPriceArray,S2Periods);
   ArrayResize(LowPriceArray,S2Periods);
   for(pricecounter=0;pricecounter<S2Periods;pricecounter++)
      {
      HighPriceArray[pricecounter]=High[pricecounter+1];
      LowPriceArray[pricecounter]=Low[pricecounter+1];
      }
      
   S1LongEntryBar=ArrayMaximum(HighPriceArray,S1Periods,0);
   S1ShortEntryBar=ArrayMinimum(LowPriceArray,S1Periods,0);
   S2LongEntryBar=ArrayMaximum(HighPriceArray,WHOLE_ARRAY,0);
   S2ShortEntryBar=ArrayMinimum(LowPriceArray,WHOLE_ARRAY,0);

   S1LongExitBar=ArrayMinimum(LowPriceArray,10,0);
   S1ShortExitBar=ArrayMaximum(HighPriceArray,10,0);
   
   S1LongEntry=HighPriceArray[S1LongEntryBar];
   S1ShortEntry=LowPriceArray[S1ShortEntryBar];
   S2LongEntry=HighPriceArray[S2LongEntryBar];
   S2ShortEntry=LowPriceArray[S2ShortEntryBar];

   S1LongExit=LowPriceArray[S1LongExitBar];
   S1ShortExit=HighPriceArray[S1ShortExitBar];
   S2LongExit=S1ShortEntry;
   S2ShortExit=S1LongEntry;
   }



//+------------------------------------------------------------------+
//| Manage comments                                                  |
//+------------------------------------------------------------------+
void managecomments(string addcomment)
   {
   string basemessage = "Current Turtle Order Entry Information\n";
   string tempcomments[];
   int commentscroll;
   string output = basemessage;
   int CommentCount = ArrayRange(allcomments, 0);
   if(CommentCount<MaxCommentsToShow)
      {
      ArrayResize(tempcomments,CommentCount+1);
      ArrayCopy(tempcomments,allcomments,1,0,WHOLE_ARRAY);
      }
   else
      {
      ArrayResize(tempcomments,MaxCommentsToShow);
      ArrayCopy(tempcomments,allcomments,1,0,MaxCommentsToShow-1);
      }   
   tempcomments[0]=addcomment;
   CommentCount = ArrayRange(tempcomments, 0);
   ArrayResize(allcomments,CommentCount);
   ArrayCopy(allcomments,tempcomments,0,0,CommentCount);
   
   for(commentscroll=0;commentscroll<CommentCount;commentscroll++)
      {
      output = output + allcomments[commentscroll] +"\n";
      }    
   Comment(output);
   }

void drawentries(double S1Long, double S2Long, double S1Short, double S2Short, double S1LongExit, double S1ShortExit)
   {
   ObjectDelete("S1Long_Entry");
   ObjectDelete("S1Long_EntrySign");
   ObjectDelete("S2Long_Entry");
   ObjectDelete("S2Long_EntrySign");

   ObjectDelete("S2Short_EntrySign");
   ObjectDelete("S2Short_Entry");
   ObjectDelete("S1Short_EntrySign");
   ObjectDelete("S1Short_Entry");
   
   ObjectDelete("S1Long_ExitSign");
   ObjectDelete("S1Long_Exit");
   
   ObjectDelete("S1Short_ExitSign");
   ObjectDelete("S1Short_Exit");
   
   if(S1LongExit!=S1Short)
      {
      ObjectCreate("S1Long_Exit", OBJ_HLINE, 0, 0, S1LongExit);// Creating obj.
      ObjectSet("S1Long_Exit",OBJPROP_COLOR,S1ExitLinesColor);
      ObjectCreate("S1Long_ExitSign", OBJ_TEXT, 0, Time[0], S1LongExit);// Creating obj.
      ObjectSetText("S1Long_ExitSign", "S1 Long Exit: "+DoubleToStr(S1LongExit,Digits), LabelFontSize, "Verdana", LabelColor);
      }
   
   if(S1ShortExit!=S1Long)
      {   
      ObjectCreate("S1Short_Exit", OBJ_HLINE, 0, 0, S1ShortExit);// Creating obj.
      ObjectSet("S1Short_Exit",OBJPROP_COLOR,S1ExitLinesColor);
      ObjectCreate("S1Short_ExitSign", OBJ_TEXT, 0, Time[0], S1ShortExit);// Creating obj.
      ObjectSetText("S1Short_ExitSign", "S1 Short Exit: "+DoubleToStr(S1ShortExit,Digits), LabelFontSize, "Verdana", LabelColor);
      }
      
   if(S1Long==S2Long)
      {
      ObjectCreate("S1Long_Entry", OBJ_HLINE, 0, 0, S1Long);// Creating obj.
      ObjectSet("S1Long_Entry",OBJPROP_COLOR,S1andS2LongEntryLineColor);
      ObjectCreate("S1Long_EntrySign", OBJ_TEXT, 0, Time[0], S1Long);// Creating obj.
      ObjectSetText("S1Long_EntrySign", "S1 & S2: "+DoubleToStr(S1Long,Digits), LabelFontSize, "Verdana", LabelColor);
      }
   else
      {
      ObjectCreate("S1Long_Entry", OBJ_HLINE, 0, 0, S1Long);// Creating obj.
      ObjectSet("S1Long_Entry",OBJPROP_COLOR,S1LongEntryLineColor);
         
      ObjectCreate("S1Long_EntrySign", OBJ_TEXT, 0, Time[0], S1Long);// Creating obj.
      ObjectSetText("S1Long_EntrySign", "S1: "+DoubleToStr(S1Long,Digits), LabelFontSize, "Verdana", LabelColor);
         
      ObjectCreate("S2Long_Entry", OBJ_HLINE, 0, 0, S2Long);// Creating obj.
      ObjectSet("S2Long_Entry",OBJPROP_COLOR,S2LongEntryLineColor);
         
      ObjectCreate("S2Long_EntrySign", OBJ_TEXT, 0, Time[0], S2Long);// Creating obj.
      ObjectSetText("S2Long_EntrySign", "S2: "+DoubleToStr(S2Long,Digits), LabelFontSize, "Verdana", LabelColor);
      }
   
   //======
      
   if(S1Short==S2Short)
      {
      ObjectCreate("S1Short_Entry", OBJ_HLINE, 0, 0, S1Short);// Creating obj.
      ObjectSet("S1Short_Entry",OBJPROP_COLOR,S1andS2ShortEntryLineColor);
   
      ObjectCreate("S1Short_EntrySign", OBJ_TEXT, 0, Time[0], S1Short);// Creating obj.
      ObjectSetText("S1Short_EntrySign", "S1 & S2: "+DoubleToStr(S1Short,Digits), LabelFontSize, "Verdana", LabelColor);
      }
   else
      {
      ObjectCreate("S1Short_Entry", OBJ_HLINE, 0, 0, S1Short);// Creating obj.
      ObjectSet("S1Short_Entry",OBJPROP_COLOR,S1ShortEntryLineColor);
   
      ObjectCreate("S1Short_EntrySign", OBJ_TEXT, 0, Time[0], S1Short);// Creating obj.
      ObjectSetText("S1Short_EntrySign", "S1: "+DoubleToStr(S1Short,Digits), LabelFontSize, "Verdana", LabelColor);
   
      ObjectCreate("S2Short_Entry", OBJ_HLINE, 0, 0, S2Short);// Creating obj.
      ObjectSet("S2Short_Entry",OBJPROP_COLOR,S2ShortEntryLineColor);
   
      ObjectCreate("S2Short_EntrySign", OBJ_TEXT, 0, Time[0], S2Short);// Creating obj.
      ObjectSetText("S2Short_EntrySign", "S2: "+DoubleToStr(S2Short,Digits), LabelFontSize, "Verdana", LabelColor);
      }
   }

//+------------------------------------------------------------------+
//| Manage upper status                                              |
//+------------------------------------------------------------------+
void manageupperstatus(string addstatus)
   {
   ObjectDelete("Upper_Status");
   if(addstatus!="")
      {
      ObjectCreate("Upper_Status", OBJ_LABEL, 0, 0, 0);// Creating obj.
      ObjectSet("Upper_Status", OBJPROP_CORNER,1);    // Reference corner
      ObjectSet("Upper_Status", OBJPROP_XDISTANCE, 2);// X coordinate
      ObjectSet("Upper_Status", OBJPROP_YDISTANCE, 13);// Y coordinate
      ObjectSetText("Upper_Status", addstatus, 9, "Verdana", White);
      }
   }
   

//+------------------------------------------------------------------+
//| Manage lower status                                              |
//+------------------------------------------------------------------+
void managelowerstatus(string addstatus)
   {
   ObjectDelete("Lower_Status");
   if(addstatus!="")
      {
      ObjectCreate("Lower_Status", OBJ_LABEL, 0, 0, 0);// Creating obj.
      ObjectSet("Lower_Status", OBJPROP_CORNER,3);    // Reference corner
      ObjectSet("Lower_Status", OBJPROP_XDISTANCE, 2);// X coordinate
      ObjectSet("Lower_Status", OBJPROP_YDISTANCE, 1);// Y coordinate
      ObjectSetText("Lower_Status", addstatus, 9, "Verdana", Yellow);
      }
   }

void OpenS1LongPositions()
   {
   double order1price;
   double order2price;
   double order3price;
   
   OrderSend(Symbol(),OP_BUY,UnitSizing,Ask,0,LongStopLoss(Ask,CurrentATR),0,"S1",MagicNumber,0,Blue);
  
      order1price=Ask+(CurrentATR/2);
      order2price=Ask+CurrentATR;
      order3price=order2price+(CurrentATR/2);
            
      order1price=NormalizeDouble(order1price,Digits);
      order2price=NormalizeDouble(order2price,Digits);
      order3price=NormalizeDouble(order3price,Digits);
            
      OrderSend(Symbol(),OP_BUYSTOP,UnitSizing,order1price,0,LongStopLoss(order1price,CurrentATR),0,"S1",MagicNumber,0,Blue);
      OrderSend(Symbol(),OP_BUYSTOP,UnitSizing,order2price,0,LongStopLoss(order2price,CurrentATR),0,"S1",MagicNumber,0,Blue);
      OrderSend(Symbol(),OP_BUYSTOP,UnitSizing,order3price,0,LongStopLoss(order3price,CurrentATR),0,"S1",MagicNumber,0,Blue);
   }


void OpenS2LongPositions()
   {
   double order1price;
   double order2price;
   double order3price;
   
   OrderSend(Symbol(),OP_BUY,UnitSizing,Ask,0,LongStopLoss(Ask,CurrentATR),0,"S2",MagicNumber,0,Blue);
 
      order1price=Ask+(CurrentATR/2);
      order2price=Ask+CurrentATR;
      order3price=order2price+(CurrentATR/2);
            
      order1price=NormalizeDouble(order1price,Digits);
      order2price=NormalizeDouble(order2price,Digits);
      order3price=NormalizeDouble(order3price,Digits);
            
      OrderSend(Symbol(),OP_BUYSTOP,UnitSizing,order1price,0,LongStopLoss(order1price,CurrentATR),0,"S2",MagicNumber,0,Blue);
      OrderSend(Symbol(),OP_BUYSTOP,UnitSizing,order2price,0,LongStopLoss(order2price,CurrentATR),0,"S2",MagicNumber,0,Blue);
      OrderSend(Symbol(),OP_BUYSTOP,UnitSizing,order3price,0,LongStopLoss(order3price,CurrentATR),0,"S2",MagicNumber,0,Blue);
   }
   
void OpenS1ShortPositions()
   {
   double order1price;
   double order2price;
   double order3price;
   
   OrderSend(Symbol(),OP_SELL,UnitSizing,Bid,0,ShortStopLoss(Bid,CurrentATR),0,"S1",MagicNumber,0,Red);

      order1price=Bid-(CurrentATR/2);
      order2price=Bid-CurrentATR;
      order3price=order2price-(CurrentATR/2);
         
      order1price=NormalizeDouble(order1price,Digits);
      order2price=NormalizeDouble(order2price,Digits);
      order3price=NormalizeDouble(order3price,Digits);
         
      OrderSend(Symbol(),OP_SELLSTOP,UnitSizing,order1price,0,ShortStopLoss(order1price,CurrentATR),0,"S1",MagicNumber,0,Red);
      OrderSend(Symbol(),OP_SELLSTOP,UnitSizing,order2price,0,ShortStopLoss(order2price,CurrentATR),0,"S1",MagicNumber,0,Red);
      OrderSend(Symbol(),OP_SELLSTOP,UnitSizing,order3price,0,ShortStopLoss(order3price,CurrentATR),0,"S1",MagicNumber,0,Red);
    
   }
   
void OpenS2ShortPositions()
   {
   double order1price;
   double order2price;
   double order3price;
   
   OrderSend(Symbol(),OP_SELLLIMIT,UnitSizing,Bid,0,ShortStopLoss(Bid,CurrentATR),0,"S2",MagicNumber,0,Red);

      order1price=Bid-(CurrentATR/2);
      order2price=Bid-CurrentATR;
      order3price=order2price-(CurrentATR/2);
         
      order1price=NormalizeDouble(order1price,Digits);
      order2price=NormalizeDouble(order2price,Digits);
      order3price=NormalizeDouble(order3price,Digits);
         
      OrderSend(Symbol(),OP_SELLSTOP,UnitSizing,order1price,0,ShortStopLoss(order1price,CurrentATR),0,"S2",MagicNumber,0,Red);
      OrderSend(Symbol(),OP_SELLSTOP,UnitSizing,order2price,0,ShortStopLoss(order2price,CurrentATR),0,"S2",MagicNumber,0,Red);
      OrderSend(Symbol(),OP_SELLSTOP,UnitSizing,order3price,0,ShortStopLoss(order3price,CurrentATR),0,"S2",MagicNumber,0,Red);
    
   }
  
double LongStopLoss(double StartPrice, double CurrentATR)
   {
   double result;
   result=StartPrice-(CurrentATR*ATRStopLossMultiplier);
   result=NormalizeDouble(result,Digits);
   return(result);
   }
   

   
double ShortStopLoss(double StartPrice, double CurrentATR)
   {
   double result;
   result=StartPrice+(CurrentATR*ATRStopLossMultiplier);
   result=NormalizeDouble(result,Digits);
   return(result);
   }
   
void CloseS1LongPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_BUY))&&((OrderComment()=="S1")))
         {
         OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue);
         }
      }
   }
   
void CloseS2LongPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_BUY))&&((OrderComment()=="S2")))
         {
         OrderClose(OrderTicket(),OrderLots(),Bid,0,Blue);
         }
      }
   }
   
void ClosePendingLongPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_BUYSTOP)))
         {
         OrderDelete(OrderTicket());
         }
      }
   }   

int CountLongPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   int result=0;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_BUY)))
         {
         result++;
         }
      }
   return(result);
   }   
   
void CloseS1ShortPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_SELL))&&((OrderComment()=="S1")))
         {
         OrderClose(OrderTicket(),OrderLots(),Ask,0,Blue);
         }
      }
   }   
   
void CloseS2ShortPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_SELL))&&((OrderComment()=="S2")))
         {
         OrderClose(OrderTicket(),OrderLots(),Ask,0,Blue);
         }
      }
   }   
   
void ClosePendingShortPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_SELLSTOP)))
         {
         OrderDelete(OrderTicket());
         }
      }
   }
   
int CountShortPositions()
   {
   int totalorders=OrdersTotal();
   int orderscroll;
   int result=0;
   for(orderscroll=0;orderscroll<totalorders;orderscroll++)
      {
      OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
      if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_SELL)))
         {
         result++;
         }
      }
   return(result);
   }
   
void StandardStopsForShorts()
   {
   double stoplevel=10000;
   int orderscroll;
   int totalshorts=CountShortPositions();
   int totalorders=OrdersTotal();
   if(totalshorts>1)
      {
      //scroll to find the lowest stop
      for(orderscroll=0;orderscroll<totalorders;orderscroll++)
         {
         OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
         if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_SELL)))
            {
            if(OrderStopLoss()<stoplevel)
               {
               stoplevel=OrderStopLoss();
               }
            }
         }
      
      //scroll to set the stops
      for(orderscroll=0;orderscroll<totalorders;orderscroll++)
         {
         OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
         if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_SELL)))
            {
            if(stoplevel!=OrderStopLoss())
               {
               OrderModify(OrderTicket(),OrderOpenPrice(),stoplevel,OrderTakeProfit(),0,CLR_NONE);
               }
            }
         }        
      }
   }      
   
   
void StandardStopsForLongs()
   {
   double stoplevel=0;
   int orderscroll;
   int totalshorts=CountLongPositions();
   int totalorders=OrdersTotal();
   if(totalshorts>1)
      {
      //scroll to find the lowest stop
      for(orderscroll=0;orderscroll<totalorders;orderscroll++)
         {
         OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
         if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_BUY)))
            {
            if(OrderStopLoss()>stoplevel)
               {
               stoplevel=OrderStopLoss();
               }
            }
         }
      
      //scroll to set the stops
      for(orderscroll=0;orderscroll<totalorders;orderscroll++)
         {
         OrderSelect(orderscroll,SELECT_BY_POS,MODE_TRADES);
         if((OrderSymbol()==Symbol())&&(OrderMagicNumber()==MagicNumber)&&((OrderType()==OP_BUY)))
            {
            if(stoplevel!=OrderStopLoss())
               {
               OrderModify(OrderTicket(),OrderOpenPrice(),stoplevel,OrderTakeProfit(),0,CLR_NONE);
               }
            }
         }        
      }
   } 
   
double calculateLot(){

      UnitSizing = LOT;//initialDeposit*TradeRisk/100/1000;//initialDeposit*TradeRisk/100/(CurrentATR/Point)/MarketInfo(Symbol(),MODE_TICKVALUE);
      
      
     // if(MaxDrawdown!=0 && (AccountEquity()-initialDeposit)/initialDeposit*100 <= -MaxDrawdown)
      
      if(UnitSizing<0.01) 
       UnitSizing = 0.01;
      
   return UnitSizing;
}

void trendEye(){
      li_0 = 0;
      li_4 = 0;
      li_8 = 0;
      li_12 = 0;
      li_16 = 0;
      RefreshRates();
      li_20 = 0;
      if (DayOfWeek() == 1) li_20 = 1;
      l_highest_24 = iHighest(NULL, PERIOD_D1, MODE_HIGH, gi_376 + li_20 + 1, 0);
      l_datetime_28 = iTime(NULL, PERIOD_D1, l_highest_24);
      l_shift_32 = iBarShift(NULL, PERIOD_M5, l_datetime_28);
      l_highest_36 = iHighest(NULL, PERIOD_M5, MODE_HIGH, l_shift_32, 0);
      l_ihigh_40 = iHigh(NULL, PERIOD_M5, l_highest_36);
      l_datetime_48 = iTime(NULL, PERIOD_M5, l_highest_36);
      l_day_of_week_52 = TimeDayOfWeek(l_datetime_48);
      l_day_56 = TimeDay(l_datetime_48);
      l_lowest_60 = iLowest(NULL, PERIOD_D1, MODE_LOW, gi_376 + li_20 + 1, 0);
      l_datetime_64 = iTime(NULL, PERIOD_D1, l_lowest_60);
      l_shift_68 = iBarShift(NULL, PERIOD_M5, l_datetime_64);
      l_lowest_72 = iLowest(NULL, PERIOD_M5, MODE_LOW, l_shift_68, 0);
      l_ilow_76 = iLow(NULL, PERIOD_M5, l_lowest_72);
      l_datetime_84 = iTime(NULL, PERIOD_M5, l_lowest_72);
      l_day_of_week_88 = TimeDayOfWeek(l_datetime_84);
      l_day_92 = TimeDay(l_datetime_84);
      if (l_datetime_48 > l_datetime_84) {
         gs_408 = "high";
         gs_416 = WeekDay(l_day_of_week_52);
         g_day_516 = l_day_56;
         gs_432 = TermDate(l_day_56);
         li_0 = 15;
         gs_524 = "+";
      }
      if (l_datetime_48 < l_datetime_84) {
         gs_408 = "low";
         gs_416 = WeekDay(l_day_of_week_88);
         g_day_516 = l_day_92;
         gs_432 = TermDate(l_day_92);
         li_0 = -15;
         gs_524 = "";
      }
      if (gi_376 == 1) gs_424 = "Day";
      else gs_424 = "Days";
      l_highest_96 = iHighest(NULL, PERIOD_W1, MODE_HIGH, gi_380 + 1, 0);
      l_datetime_100 = iTime(NULL, PERIOD_W1, l_highest_96);
      l_shift_104 = iBarShift(NULL, PERIOD_H1, l_datetime_100);
      l_highest_108 = iHighest(NULL, PERIOD_H1, MODE_HIGH, l_shift_104, 0);
      l_ihigh_112 = iHigh(NULL, PERIOD_H1, l_highest_108);
      l_datetime_120 = iTime(NULL, PERIOD_H1, l_highest_108);
      l_month_124 = TimeMonth(l_datetime_120);
      l_day_128 = TimeDay(l_datetime_120);
      l_lowest_132 = iLowest(NULL, PERIOD_W1, MODE_LOW, gi_380 + 1, 0);
      l_datetime_136 = iTime(NULL, PERIOD_W1, l_lowest_132);
      l_shift_140 = iBarShift(NULL, PERIOD_H1, l_datetime_136);
      l_lowest_144 = iLowest(NULL, PERIOD_H1, MODE_LOW, l_shift_140, 0);
      l_ilow_148 = iLow(NULL, PERIOD_H1, l_lowest_144);
      l_datetime_156 = iTime(NULL, PERIOD_H1, l_lowest_144);
      l_month_160 = TimeMonth(l_datetime_156);
      l_day_164 = TimeDay(l_datetime_156);
      if (l_datetime_120 > l_datetime_156) {
         gs_440 = "high";
         gs_508 = month(l_month_124);
         g_day_520 = l_day_128;
         gs_464 = TermDate(l_day_128);
         li_4 = 25;
         gs_532 = "+";
      }
      if (l_datetime_120 < l_datetime_156) {
         gs_440 = "low";
         gs_508 = month(l_month_160);
         g_day_520 = l_day_164;
         gs_464 = TermDate(l_day_164);
         li_4 = -25;
         gs_532 = "";
      }
      if (gi_380 == 1) gs_456 = "Week";
      else gs_456 = "Weeks";
      l_highest_168 = iHighest(NULL, PERIOD_MN1, MODE_HIGH, gi_384 + 1, 0);
      l_datetime_172 = iTime(NULL, PERIOD_MN1, l_highest_168);
      l_shift_176 = iBarShift(NULL, PERIOD_H1, l_datetime_172);
      l_highest_180 = iHighest(NULL, PERIOD_H1, MODE_HIGH, l_shift_176, 0);
      l_ihigh_184 = iHigh(NULL, PERIOD_H1, l_highest_180);
      l_datetime_192 = iTime(NULL, PERIOD_H1, l_highest_180);
      l_month_196 = TimeMonth(l_datetime_192);
      l_day_200 = TimeDay(l_datetime_192);
      l_lowest_204 = iLowest(NULL, PERIOD_MN1, MODE_LOW, gi_384 + 1, 0);
      l_datetime_208 = iTime(NULL, PERIOD_MN1, l_lowest_204);
      l_shift_212 = iBarShift(NULL, PERIOD_H1, l_datetime_208);
      l_lowest_216 = iLowest(NULL, PERIOD_H1, MODE_LOW, l_shift_212, 0);
      l_ilow_220 = iLow(NULL, PERIOD_H1, l_lowest_216);
      l_datetime_228 = iTime(NULL, PERIOD_H1, l_lowest_216);
      l_month_232 = TimeMonth(l_datetime_228);
      l_day_236 = TimeDay(l_datetime_228);
      if (l_datetime_192 > l_datetime_228) {
         gs_472 = "high";
         gs_480 = month(l_month_196);
         g_day_504 = l_day_200;
         gs_488 = TermDate(l_day_200);
         li_8 = 30;
         gs_540 = "+";
      }
      if (l_datetime_192 < l_datetime_228) {
         gs_472 = "low";
         gs_480 = month(l_month_232);
         g_day_504 = l_day_236;
         gs_488 = TermDate(l_day_236);
         li_8 = -30;
         gs_540 = "";
      }
      if (gi_384 == 1) gs_496 = "Month";
      else gs_496 = "Months";
      l_ima_240 = iMA(NULL, PERIOD_H1, g_period_392, 0, MODE_EMA, PRICE_CLOSE, 1);
      l_ima_248 = iMA(NULL, PERIOD_D1, g_period_388, 0, MODE_EMA, PRICE_CLOSE, 0);
      l_iclose_256 = iClose(NULL, PERIOD_H1, 1);
      if (l_iclose_256 > l_ima_240) {
         li_12 = 10;
         gs_548 = "+";
         gs_564 = ">";
      }
      if (l_iclose_256 < l_ima_240) {
         li_12 = -10;
         gs_548 = "";
         gs_564 = "<";
      }
      if (Bid > l_ima_248) {
         li_16 = 20;
         gs_556 = "+";
         gs_572 = ">";
      }
      if (Bid < l_ima_248) {
         li_16 = -20;
         gs_556 = "";
         gs_572 = "<";
      }
      if (li_0 > 0) {
         ld_292 += li_0;
         li_264 = 65280;
      } else {
         ld_300 += li_0;
         li_264 = 255;
      }
      if (li_4 > 0) {
         ld_292 += li_4;
         li_268 = 65280;
      } else {
         ld_300 += li_4;
         li_268 = 255;
      }
      if (li_8 > 0) {
         ld_292 += li_8;
         li_272 = 65280;
      } else {
         ld_300 += li_8;
         li_272 = 255;
      }
      if (li_12 > 0) {
         ld_292 += li_12;
         li_276 = 65280;
      } else {
         ld_300 += li_12;
         li_276 = 255;
      }
      if (li_16 > 0) {
         ld_292 += li_16;
         li_280 = 65280;
      } else {
         ld_300 += li_16;
         li_280 = 255;
      }
      if (MathAbs(ld_292) > MathAbs(ld_300)) {
         ld_284 = ld_292;
         ls_308 = "+";
      } else {
         ld_284 = ld_300;
         ls_308 = "";
      }
      ls_336 = StringSubstr(Symbol(), 0, 6);
      if (ld_284 == 55.0 || ld_284 == 60.0) {
         ls_316 = "Sideway trend";
         li_328 = 128;
         li_332 = 32768;
         li_324 = 32768;
      }
      if (ld_284 == 65.0 || ld_284 == 70.0) {
         ls_316 = "Weak UP trend";
         li_328 = 32768;
         li_332 = 65280;
         li_324 = 32768;
      }
      if (ld_284 == 75.0 || ld_284 == 80.0 || ld_284 == 85.0) {
         ls_316 = "UP trend";
         li_328 = 7451452;
         li_332 = 65280;
         li_324 = 7451452;
      }
      if (ld_284 == 90.0 || ld_284 == 100.0) {
         ls_316 = "Strong UP trend";
         li_328 = 65280;
         li_332 = 65280;
         li_324 = 65280;
      }
      if (ld_284 == -55.0 || ld_284 == -60.0) {
         ls_316 = "Sideway trend";
         li_328 = 32768;
         li_332 = 128;
         li_324 = 128;
      }
      if (ld_284 == -65.0 || ld_284 == -70.0) {
         ls_316 = "Weak DOWN trend";
         li_328 = 128;
         li_332 = 255;
         li_324 = 128;
      }
      if (ld_284 == -75.0 || ld_284 == -80.0 || ld_284 == -85.0) {
         ls_316 = "DOWN trend";
         li_328 = 1993170;
         li_332 = 255;
         li_324 = 1993170;
      }
      if (ld_284 == -90.0 || ld_284 == -100.0) {
         ls_316 = "Strong DOWN trend";
         li_328 = 255;
         li_332 = 255;
         li_324 = 255;
      }

      TFS_Refresh(ls_336, ls_308, ld_284, ls_316, li_328, li_332, li_324);
}

string WeekDay(int ai_0) {
   string ls_ret_4;
   if (ai_0 == 0) ls_ret_4 = "Sunday";
   if (ai_0 == 1) ls_ret_4 = "Monday";
   if (ai_0 == 2) ls_ret_4 = "Tuesday";
   if (ai_0 == 3) ls_ret_4 = "Wednesday";
   if (ai_0 == 4) ls_ret_4 = "Thursday";
   if (ai_0 == 5) ls_ret_4 = "Friday";
   if (ai_0 == 6) ls_ret_4 = "Saturday";
   return (ls_ret_4);
}

string TermDate(int ai_0) {
   string ls_ret_4;
   if (ai_0 == 1 || ai_0 == 21 || ai_0 == 31) ls_ret_4 = "st";
   else {
      if (ai_0 == 2 || ai_0 == 22) ls_ret_4 = "nd";
      else {
         if (ai_0 == 3 || ai_0 == 23) ls_ret_4 = "rd";
         else ls_ret_4 = "th";
      }
   }
   return (ls_ret_4);
}

string month(int ai_0) {
   string ls_ret_4;
   if (ai_0 == 1) ls_ret_4 = "January";
   if (ai_0 == 2) ls_ret_4 = "February";
   if (ai_0 == 3) ls_ret_4 = "March";
   if (ai_0 == 4) ls_ret_4 = "April";
   if (ai_0 == 5) ls_ret_4 = "May";
   if (ai_0 == 6) ls_ret_4 = "June";
   if (ai_0 == 7) ls_ret_4 = "July";
   if (ai_0 == 8) ls_ret_4 = "August";
   if (ai_0 == 9) ls_ret_4 = "September";
   if (ai_0 == 10) ls_ret_4 = "October";
   if (ai_0 == 11) ls_ret_4 = "November";
   if (ai_0 == 12) ls_ret_4 = "December";
   return (ls_ret_4);
}

void TFS_display_small(string a_text_0, string as_8, double ad_16, string a_text_24, color a_color_32, color a_color_36, color a_color_40) {
   ObjectCreate("_symbol_", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("_symbol_", a_text_0, 7, "Arial Black", g_color_396);
   ObjectSet("_symbol_", OBJPROP_CORNER, 3);
   ObjectSet("_symbol_", OBJPROP_XDISTANCE, X_box + 8);
   ObjectSet("_symbol_", OBJPROP_YDISTANCE, Y_box + 36);
   ObjectCreate("_line1", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("_line1", "----------------------------------------------", 9, "Arial", g_color_404);
   ObjectSet("_line1", OBJPROP_CORNER, 3);
   ObjectSet("_line1", OBJPROP_XDISTANCE, X_box + 5);
   ObjectSet("_line1", OBJPROP_YDISTANCE, Y_box + 29);
   ObjectCreate("trend_logo_1", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("trend_logo_1", ".:", 14, "Arial Black", a_color_32);
   ObjectSet("trend_logo_1", OBJPROP_CORNER, 3);
   ObjectSet("trend_logo_1", OBJPROP_XDISTANCE, X_box + 172);
   ObjectSet("trend_logo_1", OBJPROP_YDISTANCE, Y_box + 14);
   ObjectCreate("trend_logo_2", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("trend_logo_2", ":.", 14, "Arial Black", a_color_36);
   ObjectSet("trend_logo_2", OBJPROP_CORNER, 3);
   ObjectSet("trend_logo_2", OBJPROP_XDISTANCE, X_box + 161);
   ObjectSet("trend_logo_2", OBJPROP_YDISTANCE, Y_box + 14);
   ObjectCreate("trend_comment", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("trend_comment", a_text_24, 7, "Verdana", g_color_400);
   ObjectSet("trend_comment", OBJPROP_CORNER, 3);
   ObjectSet("trend_comment", OBJPROP_XDISTANCE, X_box + 45);
   ObjectSet("trend_comment", OBJPROP_YDISTANCE, Y_box + 19);
   ObjectCreate("trend_value", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("trend_value", as_8 + DoubleToStr(ad_16, 0), 9, "Arial Black", a_color_40);
   ObjectSet("trend_value", OBJPROP_CORNER, 3);
   ObjectSet("trend_value", OBJPROP_XDISTANCE, X_box + 8);
   ObjectSet("trend_value", OBJPROP_YDISTANCE, Y_box + 16);
   ObjectCreate("_line3", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("_line3", "----------------------------------------------", 9, "Arial", g_color_404);
   ObjectSet("_line3", OBJPROP_CORNER, 3);
   ObjectSet("_line3", OBJPROP_XDISTANCE, X_box + 5);
   ObjectSet("_line3", OBJPROP_YDISTANCE, Y_box + 8);
   ObjectCreate("copyright", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("copyright", "»»»   2007 © Forexinn Anatoliy Unlimited   «««", 8, "Arial Narrow", g_color_404);
   ObjectSet("copyright", OBJPROP_CORNER, 3);
   ObjectSet("copyright", OBJPROP_XDISTANCE, X_box + 8);
   ObjectSet("copyright", OBJPROP_YDISTANCE, Y_box + 2);
}

void TFS_Refresh(string a_text_0, string as_8, double ad_16, string a_text_24, color a_color_32, color a_color_36, color a_color_40){
   ObjectDelete("_symbol_");
   ObjectDelete("_line1");
   ObjectDelete("trend_logo_1");
   ObjectDelete("trend_logo_2");
   ObjectDelete("trend_comment");
   ObjectDelete("trend_value");
   ObjectDelete("_line3");
   ObjectDelete("copyright");
   TFS_display_small(ls_336, ls_308, ld_284, ls_316, li_328, li_332, li_324);
}