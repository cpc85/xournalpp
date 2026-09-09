/* Notizregal: offline Ogg Vorbis / WAV -> PCM16 mono, 16000 Hz.
   Streaming conversion; original file is read-only. MIT license, see LICENSE-Notizregal.txt. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <wchar.h>
#include "stb_vorbis.c"
#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"
#ifdef _WIN32
#define PATH_T wchar_t
#define OPEN(p,m) _wfopen(p,L##m)
#define ENTRY wmain
#else
#define PATH_T char
#define OPEN(p,m) fopen(p,m)
#define ENTRY main
#endif
static void u16(FILE *f,uint16_t v){fputc(v&255,f);fputc(v>>8,f);}
static void u32(FILE *f,uint32_t v){u16(f,(uint16_t)v);u16(f,(uint16_t)(v>>16));}
static void header(FILE *f,uint32_t bytes){fseek(f,0,SEEK_SET);fwrite("RIFF",1,4,f);u32(f,36+bytes);fwrite("WAVEfmt ",1,8,f);u32(f,16);u16(f,1);u16(f,1);u32(f,16000);u32(f,32000);u16(f,2);u16(f,16);fwrite("data",1,4,f);u32(f,bytes);}
typedef struct {double b0,b1,b2,a1,a2,z1,z2;} Biquad;
static Biquad lowpass(double rate,double q){double w=2*3.141592653589793*7000/rate,co=cos(w),a=sin(w)/(2*q);Biquad b={0};b.b0=(1-co)/2/(1+a);b.b1=(1-co)/(1+a);b.b2=b.b0;b.a1=-2*co/(1+a);b.a2=(1-a)/(1+a);return b;}
static double filtered(Biquad *b,double x){double y=b->b0*x+b->z1;b->z1=b->b1*x-b->a1*y+b->z2;b->z2=b->b2*x-b->a2*y;return y;}
int ENTRY(int argc,PATH_T **argv){
 if(argc!=3){fprintf(stderr,"Usage: audio-convert input.ogg-or-wav output.wav\n");return 2;}
 FILE *in=OPEN(argv[1],"rb");if(!in){fprintf(stderr,"Cannot open input.\n");return 3;}
 unsigned char magic[4];if(fread(magic,1,4,in)!=4){fclose(in);fprintf(stderr,"Empty input.\n");return 3;}rewind(in);
 int isOgg=!memcmp(magic,"OggS",4),channels=0,rate=0,error=0;stb_vorbis *ogg=NULL;drwav wav;
 if(isOgg){ogg=stb_vorbis_open_file(in,0,&error,NULL);if(!ogg){fclose(in);fprintf(stderr,"Unsupported/corrupt Ogg (Vorbis required, no Opus). Error %d\n",error);return 4;}stb_vorbis_info info=stb_vorbis_get_info(ogg);channels=info.channels;rate=info.sample_rate;}
 else {
  fclose(in);in=NULL;
#ifdef _WIN32
  int ok=drwav_init_file_w(&wav,argv[1],NULL);
#else
  int ok=drwav_init_file(&wav,argv[1],NULL);
#endif
  if(!ok){fprintf(stderr,"Only WAV or Ogg Vorbis input is supported.\n");return 4;}channels=wav.channels;rate=wav.sampleRate;
 }
 if(channels<1||channels>32||rate<8000||rate>192000){fprintf(stderr,"Unsupported channels/sample rate.\n");error=5;goto finish;}
 FILE *out=OPEN(argv[2],"wb");if(!out){fprintf(stderr,"Cannot create output.\n");error=6;goto finish;}header(out,0);
 float *buffer=(float*)malloc((size_t)channels*2048*sizeof(float));if(!buffer){fclose(out);error=7;goto finish;}
 Biquad b1=lowpass(rate,0.5411961),b2=lowpass(rate,1.306563);double prev=0,next=0,step=rate/16000.0;uint64_t pos=0,written=0;int done=0;
 while(!done){int frames=isOgg?stb_vorbis_get_samples_float_interleaved(ogg,channels,buffer,channels*2048):(int)drwav_read_pcm_frames_f32(&wav,2048,buffer);if(frames<=0)break;
  for(int i=0;i<frames;i++,pos++){double sample=0;for(int c=0;c<channels;c++)sample+=buffer[i*channels+c];sample/=channels;if(!isfinite(sample))sample=0;
   if(rate>16000){sample=filtered(&b2,filtered(&b1,sample));}
   if(pos==0)prev=sample;
   while(next<=(double)pos){double fraction=pos==0?0:next-((double)pos-1);double value=prev+(sample-prev)*fraction;if(value>1)value=1;if(value< -1)value=-1;int16_t v=(int16_t)lrint(value*32767);u16(out,(uint16_t)v);written++;next+=step;}
   prev=sample;
   if(pos>(uint64_t)rate*4*3600){fprintf(stderr,"Maximum recording length is 4 hours.\n");error=8;done=1;break;}
  }
 }
 if(isOgg){int e=stb_vorbis_get_error(ogg);if(e){fprintf(stderr,"Vorbis decoding error %d\n",e);error=9;}}
 free(buffer);if(!written){fprintf(stderr,"No audio samples found.\n");error=10;}
 if(ferror(out)){fprintf(stderr,"Output write failed.\n");error=11;}
 header(out,(uint32_t)(written*2));if(fclose(out)!=0)error=11;
 fprintf(stderr,"Converted %llu samples, %.2f seconds, mono 16000 Hz.\n",(unsigned long long)written,written/16000.0);
finish:if(ogg)stb_vorbis_close(ogg);else drwav_uninit(&wav);if(in)fclose(in);return error;
}
