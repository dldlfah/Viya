extends RefCounted
## Replaceable local PCM placeholders, not final music/voice or external assets.
const RATE := 22050
const SPECS := {
	"fire":{"seconds":.065,"gap":.11,"priority":20,"db":-8.0},
	"hit":{"seconds":.06,"gap":.09,"priority":30,"db":-7.0},
	"hurt":{"seconds":.16,"gap":.15,"priority":80,"db":-3.0},
	"magic":{"seconds":.42,"gap":.25,"priority":70,"db":-4.0},
	"pickup":{"seconds":.085,"gap":.30,"priority":10,"db":-10.0},
	"level":{"seconds":.36,"gap":.25,"priority":90,"db":-4.0},
	"clear":{"seconds":.52,"gap":.5,"priority":100,"db":-4.0},
	"defeat":{"seconds":.46,"gap":.5,"priority":100,"db":-4.0}
}
static var cache:Dictionary={}

static func stream(kind:String) -> AudioStreamWAV:
	if not SPECS.has(kind):return null
	if cache.has(kind):return cache[kind]
	var seconds:float=SPECS[kind].seconds
	var count:int=ceili(seconds*RATE)
	var samples:=PackedFloat32Array()
	samples.resize(count)
	var peak:=.000001
	var phase:=0.0
	for index in range(count):
		var time:float=float(index)/RATE
		var progress:float=time/seconds
		# Deterministic sample-local texture; never touches any gameplay RNG.
		var noise:float=fposmod(sin(float(index+1)*12.9898)*43758.5453,1.0)*2-1
		var frequency:=180.0
		var texture:=0.0
		match kind:
			"fire":
				frequency=180-100*progress
				texture=noise*.8
			"hit":
				frequency=1400-800*progress
				texture=noise*.45
			"hurt":frequency=220-120*progress
			"magic":frequency=160+780*progress*progress
			"pickup":frequency=880 if progress<.5 else 1320
			"level":frequency=[523.25,659.25,783.99][mini(2,int(progress*3))]
			"clear":frequency=[523.25,659.25,783.99,1046.5][mini(3,int(progress*4))]
			"defeat":frequency=[329.63,261.63,196.0][mini(2,int(progress*3))]
		phase+=TAU*frequency/RATE
		var envelope:float=minf(1,time/.003)*pow(maxf(0,1-progress),2)
		var sample:float=(sin(phase)*.7+sin(phase*2)*.15+texture)*envelope
		samples[index]=sample
		peak=maxf(peak,absf(sample))
	var pcm:=PackedByteArray()
	pcm.resize(count*2)
	for index in range(count):pcm.encode_s16(index*2,roundi(samples[index]/peak*.18*32767))
	var result:=AudioStreamWAV.new()
	result.format=AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate=RATE
	result.stereo=false
	result.data=pcm
	cache[kind]=result
	return result
