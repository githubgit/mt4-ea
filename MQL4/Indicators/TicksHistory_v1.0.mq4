//+------------------------------------------------------------------+
//|                                                TicksHistory_v1.0 |
//|                              Copyright 2022, Volodymyr Pochernin |
//|                        https://github.com/githubgit/TicksHistory |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Volodymyr Pochernin"
#property link      "https://github.com/githubgit/TicksHistory"
#property version   "1.00"
#property strict
#property indicator_chart_window

#property description "Persist instrument ticks to csv file."

input string FileName="ticks";

string fName;

int fileHandle;

MqlTick lastTick;
MqlTick currTick;

ulong zeroMicroSec;
bool firstTime = true;
bool fileInit = true;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
{
  return(0);
}


void initFilename(){

   string dateTime = TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
   StringReplace(dateTime,":",".");
   
   fName = dateTime+" - account_"+AccountNumber()+"."+AccountCompany()+"."+FileName+".csv";
	fileHandle = FileOpen(fName,FILE_WRITE|FILE_CSV);

	if(fileHandle == INVALID_HANDLE)
	{  GetLastError();
	   Print("File " + fName + " open error ", GetLastError());
	   ExpertRemove();
	}else
	   FileWrite(fileHandle,"datetime","bid","ask");
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
{
   FileClose(fileHandle);
   Print("File " + fName + ".csv" + " was  successfully created");
   return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
{  
   if(firstTime) {
      //init first tick
      SymbolInfoTick(Symbol(), lastTick);
      firstTime = false;
      return(0);
   }

   SymbolInfoTick(Symbol(), currTick);
   

   if(TimeSeconds(lastTick.time) == TimeSeconds(currTick.time)){
        lastTick = currTick;
   }else {
      zeroMicroSec = GetMicrosecondCount();
      
      if(fileInit && AccountNumber()!=0){
          initFilename();
          fileInit = false;
      }
   }

   
   if(SymbolInfoTick(Symbol(), lastTick) ){
      ulong diffMicro = GetMicrosecondCount() - zeroMicroSec;//microseconds since indicator started
      ulong diffSeconds = diffMicro/1000000;
      diffSeconds = diffSeconds *1000000;
      uint milliseconds = (diffMicro - diffSeconds)/1000;
      string msc;
      
      if(milliseconds == 0)
       msc = "000";
      else if (milliseconds<10)
       msc = "00"+milliseconds;
      else if (milliseconds<100)
       msc = "0"+milliseconds;
      else msc = milliseconds;
      
      FileWrite(fileHandle, TimeToStr( lastTick.time, TIME_DATE|TIME_SECONDS)+"."+msc, DoubleToString(lastTick.bid,Digits),DoubleToString(lastTick.ask,Digits));
   }

   return(0);
}