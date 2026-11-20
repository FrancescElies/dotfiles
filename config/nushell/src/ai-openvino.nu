# speech recognition + subtitles on the Intel NPU (OpenVINO GenAI)
# First run: ov-setup

export module ai-ov {
    def root [] { $"($env.HOME)/.local/share/ov-tools" }
    def vpy [] { $"(root)/venv/bin/python" }
    def default-model [] { $"(root)/models/whisper-large-v3-turbo-int8-ov" }
    def bitmap-codecs [] {
        ["hdmv_pgs_subtitle" "dvd_subtitle" "dvb_subtitle" "xsub"]
    }

    export def --env ov-env [] {
        let lib = "/opt/intel/openvino_2026/runtime/lib/intel64"
        $env.LD_LIBRARY_PATH = (
            [
                $lib
                ($env.LD_LIBRARY_PATH? | default "")
            ]
            | where {|p| $p != "" }
            | str join ":"
        )
    }

    # NPU kernel-side + Level Zero driver (Intel linux-npu-driver)
    export def install-npu-driver [] {
        let tag = $"ubuntu((^bash -c '. /etc/os-release; echo $VERSION_ID' | str trim | str replace '.' ''))"
        let rel = (
            http get https://api.github.com/repos/intel/linux-npu-driver/releases/latest
        )
        let asset = ($rel.assets
        | where {|a| ($a.name | str contains $tag) and ($a.name | str ends-with ".tar.gz") }
        | get -o 0)
        if $asset == null { error make {msg: $"no ($tag) tarball in release ($rel.tag_name)"} }

        let tmp = (mktemp -d)
        ^curl -fL -o $"($tmp)/npu.tar.gz" $asset.browser_download_url
        ^tar -xf $"($tmp)/npu.tar.gz" -C $tmp

        do -i { sudo dpkg --purge --force-remove-reinstreq intel-driver-compiler-npu intel-fw-npu intel-level-zero-npu intel-level-zero-npu-dbgsym }
        sudo apt install -y libtbb12
        sudo dpkg -i ...(glob $"($tmp)/*.deb")

        # newer Level Zero loader (release notes pin one from this PPA)
        sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
        sudo apt install -y libze1

        rm -rf $tmp
        print $"installed NPU driver ($rel.tag_name). Reboot, then run: npu-check"
    }

    export def install-openvino [--tag: string = "2026.4.0"] {
        let src = $"($env.HOME)/src/oss/openvino"
        let url = "https://github.com/openvinotoolkit/openvino.git"
        mkdir ($src | path dirname) # creates ~/src/oss

        if ($src | path exists) {
            ^git -C $src fetch --depth 1 origin $"refs/tags/($tag):refs/tags/($tag)"
            ^git -C $src checkout $tag
            ^git -C $src submodule update --init --recursive --depth 1
        } else {
            ^git clone --branch $tag --depth 1 --recurse-submodules --shallow-submodules $url $src
        }

        sudo $"($src)/install_build_dependencies.sh"

        ^cmake -S $src -B $"($src)/build" -DCMAKE_BUILD_TYPE=Release -DENABLE_INTEL_NPU=ON -DENABLE_PYTHON=OFF
        ^cmake --build $"($src)/build" --parallel (^nproc | str trim | into int)
        sudo cmake --install $"($src)/build" --prefix /opt/intel/openvino_2026
        print "Done. Run: ov-env"
    }

    # Python helper: runs WhisperPipeline, prints segments as JSON on stdout
    def write-helper [] {
        r#'
import sys, json, wave
import numpy as np
import openvino_genai as ov

model, wav, device, lang, task, cache = sys.argv[1:7]
with wave.open(wav) as f:
    x = np.frombuffer(f.readframes(f.getnframes()), np.int16).astype(np.float32) / 32768

def run(dev):
    pipe = ov.WhisperPipeline(model, dev, CACHE_DIR=cache)
    kw = {"task": task, "return_timestamps": True}
    if lang != "auto":
        kw["language"] = f"<|{lang}|>"
    return pipe.generate(x, **kw)

try:
    r = run(device)
except Exception as e:
    print(f"[{device} failed: {e}] falling back to CPU", file=sys.stderr)
    r = run("CPU")

dur = len(x) / 16000

def seg(c):
    start = max(c.start_ts, 0.0)
    end = c.end_ts if c.end_ts >= start else dur   # -1 / bad end -> end of audio
    return {"start": start, "end": min(end, dur), "text": c.text.strip()}

segs = [seg(c) for c in r.chunks]
print(json.dumps(segs))
'# | save -f $"(root)/stt.py"
    }

    # One-time setup: ffmpeg, python venv, OpenVINO GenAI, Whisper model
    export def ov-setup [] {
        sudo apt install -y ffmpeg python3-venv wl-clipboard
        mkdir (root)
        ^python3 -m venv $"(root)/venv"
        let py = (vpy)
        ^$py -m pip install -U openvino openvino-genai huggingface_hub
        write-helper
        ov-model-get
        sudo usermod -aG render $env.USER
        print "Done. Log out/in once so the 'render' group applies, then run: npu-check"
    }

    # Download an OpenVINO-format model from Hugging Face
    export def ov-model-get [repo: string = "OpenVINO/whisper-large-v3-turbo-int8-ov"] {
        let dest = $"(root)/models/($repo | path basename)"
        let hf = $"(root)/venv/bin/hf"
        ^$hf download $repo --local-dir $dest
        print $"model: ($dest)"
    }

    # Is the NPU visible and usable?
    export def npu-check [] {
        let py = (vpy)
        {
            accel_nodes: (glob /dev/accel/*)
            kernel_module: (
            ^lsmod
            | lines
            | where {|l| $l | str starts-with "intel_vpu"}
            | length
            | $in > 0
        )
            in_render_group: (
            ^id -nG
            | str trim
            | split row " "
            | "render" in $in
        )
            openvino_devices: (
            with-env {LD_LIBRARY_PATH: ""} { ^$py -c "import openvino as ov; print(ov.Core().available_devices)" | str trim }
        )
        }
    }

    # Live NPU utilisation (Ctrl+C to stop)
    export def npu-watch [] {
        let f = "/sys/class/accel/accel0/device/npu_busy_time_us"
        mut prev = open --raw $f | str trim | into int
        loop {
            sleep 1sec
            let now = open --raw $f | str trim | into int
            print $"NPU busy: (($now - $prev) / 10000 | math round)%"
            $prev = $now
        }
    }

    def to-wav [file: path, track: int] {
        let wav = (mktemp --suffix .wav)
        let r = (
            ^ffmpeg -nostdin -loglevel error -y -i $file -map $"0:a:($track)" -vn -ac 1 -ar 16000 -c:a pcm_s16le $wav
            | complete
        )
        if $r.exit_code != 0 {
            rm -f $wav
            error make {msg: $"ffmpeg failed: ($r.stderr | str trim)"}
        }
        $wav
    }

    def run-whisper [
        wav: path
        model: path
        device: string
        lang: string
        task: string
    ] {
        let cache = $"($env.HOME)/.cache/ov-npu"
        mkdir $cache
        let py = (vpy)
        let script = $"(root)/stt.py"
        # clear LD_LIBRARY_PATH so the source-built OpenVINO (ov-env) can't clash with the pip one
        with-env {LD_LIBRARY_PATH: ""} {
        ^$py $script $model $wav $device $lang $task $cache | from json
    }
    }

    def ts [s: number, sep: string] {
        let ms = $s * 1000 | math round | into int
        let p = {|n w|
            $n | fill --alignment right --character '0' --width $w
        }
        $"(do $p ($ms // 3600000) 2):(do $p (($ms mod 3600000) // 60000) 2):(do $p (($ms mod 60000) // 1000) 2)($sep)(do $p ($ms mod 1000) 3)"
    }

    def render [segs: list<any>, format: string] {
        match $format {
            "srt" => {
                $segs | enumerate | each {|r|
                $"($r.index + 1)\n(ts $r.item.start ',') --> (ts $r.item.end ',')\n($r.item.text)\n"
            } | str join "\n"
            }
            "vtt" => {
                "WEBVTT\n\n" + ($segs | each {|s|
                $"(ts $s.start '.') --> (ts $s.end '.')\n($s.text)\n"
            } | str join "\n")
            }
            "txt" => {
                $segs | get text | str join "\n"
            }
            "json" => {
                $segs | to json
            }
            _ => { error make {msg: $"unknown format: ($format) [use srt|vtt|txt|json]"} }
        }
    }

    # Speech-to-text for any audio/video file. --task translate gives English output.
    export def stt [
    file: path
    --model: path                    # default: whisper-large-v3-turbo-int8-ov
    --device: string = "NPU"         # NPU | GPU | CPU
    --lang: string = "auto"          # en, de, fr, ...
    --task: string = "transcribe"    # transcribe | translate
    --format: string = "txt"         # txt | srt | vtt | json
    --track: int = 0                 # audio track
    --out: path                      # save to file instead of printing
] {
        let m = $model | default (default-model)
        let wav = (to-wav $file $track)
        let segs = (run-whisper $wav $m $device $lang $task)
        rm -f $wav
        let text = (render $segs $format)
        if $out != null {
            $text | save -f $out
            print $"saved: ($out)"
        } else {
            $text
        }
    }

    # List subtitle streams inside a video
    export def sub-list [video: path] {
        ^ffprobe -v error -select_streams s -show_entries "stream=index,codec_name:stream_tags=language,title" -of json $video
        | from json
        | get streams?
        | default []
        | enumerate
        | each {|r| {
        track: $r.index
        stream: $r.item.index
        codec: $r.item.codec_name
        lang: ($r.item.tags?.language? | default "und")
        title: ($r.item.tags?.title? | default "")
    } }
    }

    # Extract an embedded text subtitle track (track = position in sub-list)
    export def sub-extract [video: path, --track: int = 0, --format: string = "srt"] {
        let info = sub-list $video | get $track
        if $info.codec in (bitmap-codecs) {
            error make {
                msg: $"track ($track) is bitmap ($info.codec); needs OCR (e.g. pgsrip / SubtitleEdit), or use sub-gen"
            }
        }
        let out = (
        $video
        | path parse
        | update stem {|s| $"($s).($info.lang)"}
        | update extension $format
        | path join
    )
        ^ffmpeg -nostdin -loglevel error -y -i $video -map $"0:s:($track)" $out
        print $"saved: ($out)"
    }

    # Generate subtitles by transcribing the audio (writes video.srt or video.<lang>.srt)
    export def sub-gen [
        video: path
        --lang: string = "auto"
        --task: string = "transcribe"
        --device: string = "NPU"
        --track: int = 0
    ] {
        let ext = (if $lang == "auto" { "srt" } else { $"($lang).srt" })
        let out = (
        $video
        | path parse
        | update extension $ext
        | path join
    )
        stt $video --lang $lang --task $task --device $device --track $track --format srt --out $out
    }

    # Whisper codes (en) -> ffprobe ISO 639-2 codes (eng)
    def iso639-2 [lang: string] {
        {
            en: [eng]
            de: [deu ger]
            fr: [fra fre]
            es: [spa]
            it: [ita]
            pt: [por]
            nl: [nld dut]
            ru: [rus]
            ja: [jpn]
            zh: [zho chi]
            ko: [kor]
            ca: [cat]
            pl: [pol]
            sv: [swe]
            tr: [tur]
            ar: [ara]
            hi: [hin]
        } | get -o $lang | default [$lang]
    }

    export def sub-auto [video: path, --lang: string = "auto", --device: string = "NPU"] {
        let codes = if $lang == "auto" { [] } else { iso639-2 $lang }
        let text_subs = (
        sub-list $video
        | where {|s| $s.codec not-in (bitmap-codecs) }
        | where {|s| $lang == "auto" or $s.lang in $codes }
    )
        if ($text_subs | is-empty) {
            sub-gen $video --lang $lang --device $device
        } else {
            sub-extract $video --track ($text_subs | first | get track)
        }
    }

    # Record from the mic, transcribe on the NPU, copy text to the clipboard
    export def dictate [--secs: int = 10, --lang: string = "auto"] {
        let wav = (mktemp --suffix .wav)
        ^ffmpeg -nostdin -loglevel error -y -f pulse -i default -t $secs -ac 1 -ar 16000 -c:a pcm_s16le $wav
        let segs = (run-whisper $wav (default-model) "NPU" $lang "transcribe")
        rm -f $wav
        let text = (
        $segs
        | get text
        | str join " "
        | str trim
    )
        $text | ^wl-copy
        $text
    }
}
