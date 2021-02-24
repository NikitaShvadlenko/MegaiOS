
struct FileTypes {
    func imageName(for fileExtension: String) -> String? {
        allTypes[fileExtension]
    }
    
    let allTypes = [
        "3ds":"3d",
        "3dm":"3d",
        "3fr":"raw",
        "3g2":"video",
        "3ga":"audio",
        "3gp":"video",
        "7z":"compressed",
        "aac":"audio",
        "abr":"photoshop",
        "ac3":"audio",
        "accdb":"web_lang",
        "aep":"after_effects",
        "aet":"after_effects",
        "ai":"illustrator",
        "aif":"audio",
        "aiff":"audio",
        "ait":"illustrator",
        "ans":"text",
        "apk":"executable",
        "app":"executable",
        "arw":"raw",
        "ascii":"text",
        "asf":"video",
        "asp":"web_lang",
        "aspx":"web_lang",
        "avi":"video",
        "bay":"raw",
        "bin":"executable",
        "bmp":"image",
        "bz2":"compressed",
        "c":"web_lang",
        "cc":"web_lang",
        "cdr":"vector",
        "cgi":"web_lang",
        "class":"web_data",
        "com":"executable",
        "cmd":"executable",
        "cpp":"web_lang",
        "cr2":"raw",
        "css":"web_data",
        "cxx":"web_lang",
        "dcr":"raw",
        "db":"web_lang",
        "dbf":"web_lang",
        "dhtml":"web_data",
        "dll":"web_lang",
        "dng":"raw",
        "doc":"word",
        "docx":"word",
        "dotx":"word",
        "dwg":"cad",
        "dxf":"cad",
        "dmg":"dmg",
        "eps":"vector",
        "exe":"executable",
        "fff":"raw",
        "flac":"audio",
        "fnt":"font",
        "fon":"font",
        "gadget":"executable",
        "gif":"image",
        "gsheet":"spreadsheet",
        "gz":"compressed",
        "h":"web_lang",
        "html":"web_data",
        "heic":"image",
        "hpp":"web_lang",
        "iff":"audio",
        "inc":"web_lang",
        "indd":"indesign",
        "jar":"web_data",
        "java":"web_data",
        "jpeg":"image",
        "jpg":"image",
        "js":"web_data",
        "key":"keynote",
        "log":"text",
        "m":"web_lang",
        "mm":"web_lang",
        "m4v":"video",
        "m4a":"audio",
        "max":"3d",
        "mdb":"web_lang",
        "mef":"raw",
        "mid":"audio",
        "midi":"audio",
        "mkv":"video",
        "mov":"video",
        "mp3":"audio",
        "mp4":"video",
        "mpeg":"video",
        "mpg":"video",
        "mrw":"raw",
        "msi":"executable",
        "nb":"spreadsheet",
        "numbers":"numbers",
        "nef":"raw",
        "obj":"3d",
        "odp":"generic",
        "ods":"spreadsheet",
        "odt":"openoffice",
        "ogv":"video",
        "otf":"font",
        "ots":"spreadsheet",
        "orf":"raw",
        "pages":"pages",
        "pdb":"web_lang",
        "pdf":"pdf",
        "pef":"raw",
        "php":"web_lang",
        "php3":"web_lang",
        "php4":"web_lang",
        "php5":"web_lang",
        "phtml":"web_lang",
        "pl":"web_lang",
        "png":"image",
        "ppj":"premiere",
        "pps":"powerpoint",
        "ppt":"powerpoint",
        "pptx":"powerpoint",
        "prproj":"premiere",
        "psb":"photoshop",
        "psd":"photoshop",
        "py":"web_lang",
        "rar":"compressed",
        "rtf":"text",
        "rw2":"raw",
        "rwl":"raw",
        "sh":"web_lang",
        "shtml":"web_data",
        "sitx":"compressed",
        "sketch":"sketch",
        "sql":"web_lang",
        "srf":"raw",
        "srt":"text",
        "svg":"vector",
        "svgz":"vector",
        "tar":"compressed",
        "tbz":"compressed",
        "tga":"image",
        "tgz":"compressed",
        "tif":"image",
        "tiff":"image",
        "torrent":"torrent",
        "ttf":"font",
        "txt":"text",
        "url":"url",
        "vob":"video",
        "wav":"audio",
        "webm":"video",
        "wma":"audio",
        "wmv":"video",
        "wpd":"text",
        "wps":"word",
        "Xd":"experiencedesign",
        "xlr":"spreadsheet",
        "xls":"excel",
        "xlsx":"excel",
        "xlt":"excel",
        "xltm":"excel",
        "xml":"web_data",
        "zip":"compressed"
    ]
}
