// MetaSax - April 2021 
// Augmented version of Saxofony STK model 

class SaxInfo extends Event  
{
    dur ratey;
    dur inter;
    int switchy;
}

private class MetaSax extends Saxofony 
{

SaxInfo saxInfo;

CNoise extraNoise; 
ResonZ noiseTones[10];  // tunes to harmonic series of note but borrows very rough idea of saxophone
// in the use of more resonance for second harmonic than fundamental 
// and then a gradual decay with the 6th overtone slightly more resonant/ slightly more 
//https://pages.mtu.edu/~suits/sax_sounds/index.html
// there are so many factors that shape spectrum so this approximation is more conceptual/compositional rather than scientific 
Gain resonBump => ADSR rezEnv => dac;
extraNoise => Gain noiseBump; 

rezEnv.set(0.5::second,0.25::second,0.8,0.5::second); // just a set of init. values 
SinOsc switchGainLFO => blackhole;
SinOsc switchPressLFO2 => blackhole;

fun void saxEvent()
{
    dur att;
    dur wait;
    
    
    while (true)
    {
        saxInfo => now;
        
        saxInfo.ratey => att => rezEnv.attackTime;
        saxInfo.inter * 0.5 => wait => rezEnv.decayTime => rezEnv.releaseTime;
        
        if (saxInfo.switchy == 1)
               rezEnv.keyOff();
    }
}

fun void saxNoise(float noise)
{
    Shred updateSax;
    
    1.0 => resonBump.gain;
    
    if (noise < 1.0)
    {  updateSax.id() => Machine.remove;
       rezEnv.keyOff();
           noise => this.noiseGain;
           extraNoise !=> noiseBump;
       
    }
    else if (noise > 1.0)
    { 
       spork ~ saxEvent()  @=> updateSax;
       
       rezEnv.keyOn();
       0.5 => this.noiseGain;
       
       for (0 => int o; o < noiseTones.cap()-1; o++)
       {
               70 => noiseTones[o].Q;

           this.freq() * (o + 1) => noiseTones[o].freq; // overtones
           
           if (o != 1 && o != 5)
               1.0 - o => noiseTones[o].gain;
           else
               (1.0 - o) * 1.5 => noiseTones[o].gain;
           
           noiseBump => noiseTones[o] => resonBump;
       }
     }
}

//overloaded gain func 
fun void gain(float gainy,float switchFreq, int switchRate, string switchy)  // switch rate is a kind of "grain rate" 
{
    Shred square1;
    
    switchFreq => switchGainLFO.freq;
    
    switchRate => int rateSq; 
    
    if (switchy == "On")
       spork ~ square1Gain(rateSq,gainy) @=> square1;
    
    if (switchy == "Off")
        square1.id() => Machine.remove;
    
}

fun void square1Gain(int switchRate, float gainy)
{
        float squareLo;

   while (true)
{
    Math.fabs(switchGainLFO.last()) => squareLo;
    squareLo * (gainy) => this.gain;
    switchRate::ms => now;
}
}

// overloaded pressure func 
fun float pressure(float press, float switchFreq, int switchRate, string switchy)  // switch rate is a kind of "grain rate" 
{
    Shred square2;
    
    switchFreq => switchPressLFO2.freq;
    
     if (switchy == "On")
       spork ~ square2Press(switchRate,press) @=> square2;
    
    if (switchy == "Off")
        square2.id() => Machine.remove;
}

fun void square2Press(int rates, float pressy)
{
    
    float squareLo;
    
    while (true)
    {
        Math.fabs(switchPressLFO2.last()) => squareLo;
        (squareLo * pressy) => this.pressure;
        rates::ms => now;
    }
}

//flange routing for vibrato func

SinOsc flangerLfo => blackhole;

this => Echo ech => Gain echOut;
ech => Gain flangeFB => ech;
0.35 => flangeFB.gain;
1::second => ech.max;

// flange func - to be called by overloaded vibratoFreq func
fun void setFlange(float sweep)
{
    sweep => flangerLfo.freq;
    50. => float base; // axis for delay  
    45. => float mod; // mod should be less than base to avoid error with setdelay 
    float  flangeTime;
    while(true)
    {
        base + (flangerLfo.last() * mod) => flangeTime;
        flangeTime::ms => ech.delay;
        1::ms => now;
    }
}


// overloaded vibrato Freq function 
fun float vibratoFreq(float vib, float flangeSweep, string flangeSwitch)
{
    Shred makeFlange;
    
    if ( vib < 1.0)  
         vib => this.vibratoFreq;
    
    if (vib > 1.0 && flangeSwitch == "On")
    {echOut => dac;
    spork ~ setFlange(flangeSweep) @=> makeFlange;}
     
    if (flangeSwitch == "Off")
    {   echOut !=> dac;
    makeFlange.id() => Machine.remove;}
}

// this controls timing/pitch info 
fun void setSax(int MIDIbaseNote, string noteDist, string gainDist, float notesOn, dur ratey, dur interDelay)
{

// Referential Pitch Collections 

[0,2,4,7,9] @=> int pentaMaj[];
[0,3,5,7,10] @=> int pentaMin[];
[0,4,7,10,17] @=> int thirteenth[];
[0,4,6,10,12] @=> int flatFive[]; 

int trans;
int transtest;
      float gainScale;

float saxfreq;

    
    while (true)
    {
        
        for ( 0 => int v; v < pentaMaj.cap()-1; v++)
        {
            
            if (gainDist == "rand")
               Math.random2f(0.1,0.9) => gainScale;
                            
            if (gainDist == "uniform")
               1.0 => gainScale;
          
            (Math.random2(0,4) == 1) => transtest;
           
             if (transtest == 2)
                 -12 => trans;
             else if (transtest == 1)
                  12 => trans;
             else
                  0 => trans;
        
             if (noteDist == "pentaMaj")
            {        
               Std.mtof(MIDIbaseNote + (pentaMaj[Math.random2(0,pentaMaj.cap()-1)] + trans)) => this.freq => saxfreq;}

            if (noteDist == "pentaMin")
            {        
               Std.mtof(MIDIbaseNote + (pentaMin[Math.random2(0,pentaMin.cap()-1)] + trans)) => this.freq => saxfreq;}

            if (noteDist == "thirteenth")
            {        
               Std.mtof(MIDIbaseNote + (thirteenth[Math.random2(0,thirteenth.cap()-1)] + trans)) => this.freq => saxfreq;}
  
            if (noteDist == "flatFive")
            {        
               Std.mtof(MIDIbaseNote + (flatFive[Math.random2(0,flatFive.cap()-1)] + trans)) => this.freq => saxfreq;}
                    
            gainScale * notesOn => this.noteOn;
        
           ratey => now;
           this.noteOff;
           1 => saxInfo.switchy;
           ratey => saxInfo.ratey;
           saxInfo.signal();
         }
            interDelay => now;
            interDelay => saxInfo.inter;
            saxInfo.signal();
      }
   }
}

//////////////////////// "SCORE"  ////////////////////  
// pretty "out there" but can be made more sax-like by slowing down bending/LFO-type effects 
MetaSax saxy => Envelope e => NRev rev => Gain main => dac; 




0.2 => rev.mix;
0.7 => main.gain;
10::second => e.duration;
e.keyOn();

// set sax func is used last because of infinite loop

saxy.saxNoise(1.1); // if > 1.0, "tuned" noise generator kicks in 

//saxy.gain(0.5); // standard .gain i.e. belongs to each ChucK UGen

saxy.gain(0.5,3.8,50, "On"); // overloaded so that gain switches on/off rapily using LFO

//saxy.pressure(0.1); // standard version inherited from STK UGen 
// works but subtle??? in 0.0 - 1.0 range 

saxy.pressure(0.5,1.5,1000,"On"); 
//works , but again I think that the inherited .pressure is a bit unpredictable to begin with  

//saxy.vibratoFreq(0.1); // standard version inherited from STK UGen 
saxy.vibratoFreq(0.5,20.,"On"); // overloaded version with added flange 
// flange has a little extra echo on it because of large delay time being modulated + use of feedback on delay 

// controls pitch/dur params 
saxy.setSax(36,"thirteenth","rand", 0.6, 150::ms, 1000::ms);
1::day => now;
        