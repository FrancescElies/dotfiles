#
# ffmpeg -i VIDEO.mp4 -vf unsharp=13:13:5 VIDEO-unsharp.mp4

export module youtube {
    export def download-audio [ url: string ] {
        let yt_dlp = "~/bin/yt-dlp" | path expand
        mut args = ['-x' '--audio-format=vorbis']
        python $yt_dlp  ...$args $url
    }

    export def download-video [
        url: string
        --sub-lang: string  # with subtitles language, e.g. de, tr, es, en
    ] {
        let yt_dlp = "~/bin/yt-dlp" | path expand
        mut args = []
        if ($sub_lang | is-not-empty) { $args = ($args | append $'--write-sub --sub-lang ($sub_lang)' ) }

        python $yt_dlp  ...$args $url
    }

}
export module video {
    # Reduces video size and converts to mp4
    # See https://stackoverflow.com/questions/12026381/ffmpeg-converting-mov-files-to-mp4
    export def shrink [input_video: path] {
        ffmpeg -i $input_video -vcodec libx265 -crf 28  $"($input_video).mp4"
    }
    # One could download move parts like follows from some website
    # 400 is just an arbitrary number of how may parts there are
    # 1..400 | par-each { |x| curl $"mylink/part-($x)" -o $x -fS }
    export def concat-all-in-folder [folder: path] {
        cd $folder
        ls | get name | sort --natural | each { $"file ($in)" } | save -f inputs.txt
        ffmpeg -f concat -safe 0 -i inputs.txt -c copy $"($folder | path basename).mkv"
    }
}

export module image {
    # reduces jpg size using mogrify from imagemagick
    export def "shrink quality" [
        infile: path, # an image file supported by imagemagick
        quality: int = 10, # JPEG(1=lowest, 100=highest) see https://imagemagick.org/script/command-line-options.php#quality for other formats
        --outdir: path = './_reduced_images'
    ] {
        mkdir $outdir
        cp -f $infile $outdir
        let outfile = ($outdir | path join  ($infile | path basename))
        mogrify -quality $quality $outfile
    }

    # reduces jpg size using pngcrush
    export def "shrink png" [
        infile: path, # a jpg/jpeg file
        --outdir: path = './_reduced_images'
    ] {
        mkdir $outdir
        cp -f $infile $outdir
        let outfile = ($outdir | path join ($infile | path basename))
        pngcrush $infile $outfile
    }

    # reduces jpg size using jpegoptim
    export def "shrink jpg" [
        infile: path, # a jpg/jpeg file
        --size: string = '100k', #
        --outdir: path = './_reduced_images'
    ] {
        mkdir $outdir
        cp -f $infile $outdir
        let outfile = ($outdir | path join ($infile | path basename))
        jpegoptim --size $size $outfile
    }

}

export alias "pdf gettext" = pymupdf gettext

# reduces pdf size using gs
export def "pdf shrink" [
    infile: path, # a pdf file
    outputpdf: path = output.pdf,
    # -dPDFSETTINGS=/screen     lower quality and smaller size. (72 dpi)
    # -dPDFSETTINGS=/ebook      default,  slightly larger size (150 dpi)
    # -dPDFSETTINGS=/prepress   higher size and quality (300 dpi)
    # -dPDFSETTINGS=/printer    printer type quality (300 dpi)
    # -dPDFSETTINGS=/default    useful for multiple purposes. Can cause large PDFS.
    pdfsettings: string = "/ebook"
] {
    ^gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 $"-dPDFSETTINGS=($pdfsettings)" -dNOPAUSE -dQUIET -dBATCH $"-sOutputFile=($outputpdf)" $infile
}


def "nu-complete list-d2" [] { ls *.d2 | get name }
# terrastruct/d2 diagram helper
export def --wrapped "diagram edit-and-watch" [name: path@"nu-complete list-d2" ...rest] {
    let filename = if ($name | str contains '.d2') { $name } else { $"($name).d2" }
    if not ($filename | path exists) { echo 'x -> y -> z' | save -f $filename  }
    # wezterm cli split-pane --down --percent 30 -- watchexec -w $filename d2 $filename
    wezterm cli split-pane --bottom --percent 30 -- d2 --watch $filename ...$rest
    nvim $filename
}

# rsync that works with FAT formatted usbs, (-c) checksum, (-r) recursive, (-t) preserve modification times, (-P) keep partially transferred files and show progress
export alias rsync-fat = ^rsync -rtcvP --update

