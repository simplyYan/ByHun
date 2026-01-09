import base64
import os
import random
import re
import tempfile
import zipfile
from typing import List, Set


# Anti-debugging and integrity check code with multiple techniques
_ANTI_DEBUG_CODE = """
(function(){
    var _0x=function(){var _=[],_1='',_2='';for(var _3=0;_3<arguments.length;_3++){var _4=arguments[_3];for(var _5=0;_5<_4.length;_5++){var _6=_4.charCodeAt(_5);_.push(String.fromCharCode(_6^0x42));}}return _.join('');};
    var _dbg=function(_){var _1=String.fromCharCode(100,101,98,117,103,103,101,114);return typeof window[_1]==='function'||typeof window[_0x(_1)]==='function';};
    setInterval(function(){try{if(_dbg()){throw new Error();}if(typeof console!=='undefined'&&(console.log.toString().length!==console.log.toString().length||console.debug.toString().length!==console.debug.toString().length)){throw new Error();}}catch(e){window.location='about:blank';}},500);
    var _dev=function(){return /DevTools/.test(window.navigator.userAgent)||window.outerHeight-window.innerHeight>200||window.outerWidth-window.innerWidth>200;};
    setInterval(function(){try{if(_dev()){throw new Error();}}catch(e){document.body.innerHTML='';}},1000);
    var _c=function(_){var _1=0;for(var _2=0;_2<_.length;_2++){_1+=_.charCodeAt(_2);}return _1;};
    var _v=_c('%CHECKSUM%');
    var _f=function(_){try{Object.defineProperty(_,'cookie',{get:function(){return '';},set:function(){}});}catch(e){}};
    _f(document);
    var _e=function(){var _1=function(){};return _1.toString().indexOf('native')!==-1;};
    if(!_e()){setTimeout(function(){window.location='about:blank';},100);}
})();
"""


def _hex_encode(data: str) -> str:
    """Encode string to hex"""
    return ''.join(f'\\x{ord(c):02x}' for c in data)


def _rot13(text: str) -> str:
    """ROT13 encoding"""
    result = []
    for char in text:
        if 'a' <= char <= 'z':
            result.append(chr((ord(char) - ord('a') + 13) % 26 + ord('a')))
        elif 'A' <= char <= 'Z':
            result.append(chr((ord(char) - ord('A') + 13) % 26 + ord('A')))
        else:
            result.append(char)
    return ''.join(result)


def _xor_encode(data: str, key: int) -> str:
    """XOR encoding with key"""
    return ''.join(chr(ord(c) ^ key) for c in data)


def _split_into_chunks(text: str, min_chunk: int = 50, max_chunk: int = 200) -> List[str]:
    """Split text into random chunks"""
    chunks = []
    i = 0
    while i < len(text):
        chunk_size = random.randint(min_chunk, max_chunk)
        chunks.append(text[i:i + chunk_size])
        i += chunk_size
    return chunks


def _generate_random_var_name(length: int = 8) -> str:
    """Generate random variable name with unicode characters"""
    chars = '_$' + ''.join(chr(i) for i in range(0x3040, 0x309F))  # Hiragana
    return ''.join(random.choice(chars) for _ in range(length))


def _generate_dead_code(amount: int = 3) -> str:
    """Generate dead code to confuse deobfuscators"""
    dead_code = []
    var_names = [_generate_random_var_name() for _ in range(amount * 2)]
    
    for i in range(amount):
        var_name = var_names[i]
        var_name2 = var_names[i + amount] if i + amount < len(var_names) else _generate_random_var_name()
        operations = [
            f"var {var_name}=function(){{return Math.random()*1000;}};var {var_name2}={var_name}();",
            f"var {var_name}=[1,2,3,4,5].map(function(x){{return x*Math.PI;}});{var_name2}={var_name}.reduce(function(a,b){{return a+b;}},0);",
            f"var {var_name}=setTimeout(function(){{}},Math.floor(Math.random()*100));clearTimeout({var_name});",
            f"var {var_name}=new Date().getTime()%1000;var {var_name2}=String({var_name}).split('').reverse().join('');",
            f"var {var_name}=String.fromCharCode(65,66,67).split('').reverse().join('');var {var_name2}=function(_){{return _+Math.random();}};{var_name2}({var_name}.length);",
            f"var {var_name}=function(_1,_2){{return _1>_2?_1:_2;}};var {var_name2}={var_name}(Math.random(),Math.random());",
            f"var {var_name}=Array(10).fill(0).map(function(_,i){{return i*i;}});var {var_name2}={var_name}.filter(function(x){{return x>5;}}).length;",
            f"var {var_name}=Object.keys({{a:1,b:2,c:3}});var {var_name2}={var_name}.forEach(function(k){{return k.length;}});"
        ]
        dead_code.append(random.choice(operations))
    
    # Add some conditional dead code
    if_var = _generate_random_var_name()
    dead_code.append(f"var {if_var}=Math.random()>0.5;if({if_var}){{var {_generate_random_var_name()}=function(){{return 'never';}};}}else{{var {_generate_random_var_name()}=function(){{return 'executed';}};}}")
    
    return '\n    '.join(dead_code)


def _obfuscate_string_literal(s: str) -> str:
    """Heavily obfuscate a string literal"""
    methods = [
        lambda x: f"atob('{base64.b64encode(x.encode()).decode()}')",
        lambda x: f"String.fromCharCode({','.join(str(ord(c)) for c in x)})",
        lambda x: f"[{','.join(repr(c) for c in x)}].join('')",
        lambda x: _split_string_encode(x),
        lambda x: f"btoa(String.fromCharCode({','.join(str(ord(c)) for c in base64.b64decode(x.encode()).decode())}))" if len(x) > 0 else "''",
    ]
    method = random.choice(methods)
    return method(s)


def _split_string_encode(s: str) -> str:
    """Split string into parts and encode each"""
    if len(s) == 0:
        return "''"
    if len(s) <= 3:
        return repr(s)
    parts = _split_into_chunks(s, 2, 5)
    encoded_parts = []
    for part in parts:
        enc = random.choice([
            lambda x: f"atob('{base64.b64encode(x.encode()).decode()}')",
            lambda x: f"String.fromCharCode({','.join(str(ord(c)) for c in x)})",
        ])
        encoded_parts.append(enc(part))
    return '+'.join(encoded_parts)


def obfuscate_js(js_text: str) -> str:
    """Advanced multi-layer JavaScript obfuscation"""
    # Layer 1: Calculate checksum for integrity
    checksum = sum(ord(c) for c in js_text) % 10000
    
    # Layer 2: Add dead code at the beginning
    dead_code = _generate_dead_code(random.randint(5, 10))
    
    # Layer 3: Multiple encoding layers
    # First encode with base64
    layer1 = base64.b64encode(js_text.encode("utf-8")).decode("ascii")
    
    # Second layer: ROT13
    layer2 = _rot13(layer1)
    
    # Third layer: XOR with random key
    xor_key = random.randint(1, 255)
    layer3_bytes = _xor_encode(layer2, xor_key).encode('latin-1', errors='ignore')
    layer3 = base64.b64encode(layer3_bytes).decode("ascii")
    
    # Layer 4: Additional base64 encoding (double encoding)
    layer4 = base64.b64encode(layer3.encode("utf-8")).decode("ascii")
    
    # Generate random variable names
    var_atob = _generate_random_var_name()
    var_rot13 = _generate_random_var_name()
    var_xor = _generate_random_var_name()
    var_result = _generate_random_var_name()
    var_key = _generate_random_var_name()
    var_decode = _generate_random_var_name()
    var_exec = _generate_random_var_name()
    var_temp = _generate_random_var_name()
    var_bytes = _generate_random_var_name()
    
    # Create obfuscated decoder function with multiple layers
    decoder_code = f"""
(function(){{
    {dead_code}
    var {var_key}={xor_key};
    var {var_atob}=function(_){{var _1=window.atob||function(_2){{var _3='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';var _4='',_5='',_6='',_7='',_8='',_9='',_a='',_b='';_2=String(_2).replace(/[^A-Za-z0-9\\+\\/\\=]/g,'');for(var _c=0;_c<_2.length;){{_7=_3.indexOf(_2.charAt(_c++));_8=_3.indexOf(_2.charAt(_c++));_9=_3.indexOf(_2.charAt(_c++));_a=_3.indexOf(_2.charAt(_c++));_b=(_7<<2)|(_8>>4);_6=(_8&15)<<4|(_9>>2);_c=((_9&3)<<6)|_a;_4+=String.fromCharCode(_b);if(_9!=64){{_4+=String.fromCharCode(_6);}}if(_a!=64){{_4+=String.fromCharCode(_c);}}_b=_6=_c='';_7=_8=_9=_a='';}}return _4.replace(/\\0+$/,'');}};return _1(_);}};
    var {var_rot13}=function(_){{var _1='';for(var _2=0;_2<_.length;_2++){{var _3=_[_2];if('a'<=_3&&_3<='z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-97+13)%%26+97);}}else if('A'<=_3&&_3<='Z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-65+13)%%26+65);}}else{{_1+=_3;}}}}return _1;}};
    var {var_xor}=function(_,_k){{var _1='';for(var _2=0;_2<_.length;_2++){{_1+=String.fromCharCode(_.charCodeAt(_2)^_k);}}return _1;}};
    var {var_result}='{layer4}';
    {var_result}={var_atob}({var_result});
    {var_result}={var_atob}({var_result});
    {var_result}={var_rot13}({var_result});
    var {var_bytes}=new Uint8Array({var_result}.split('').map(function(_){{return _.charCodeAt(0);}}));
    {var_temp}=String.fromCharCode.apply(null,Array.from({var_bytes}));
    {var_result}={var_xor}({var_temp},{var_key});
    {var_result}={var_atob}({var_result});
    var {var_exec}=function(_){{try{{(function(){{(0,eval)(_);}})();}}catch(_e){{setTimeout(function(){{{var_exec}(_);}},10);}}}};
    {var_exec}({var_result});
}})();
"""
    
    # Add anti-debugging wrapper
    anti_debug = _ANTI_DEBUG_CODE.replace('%CHECKSUM%', str(checksum))
    
    # Combine anti-debug and decoder
    combined_code = anti_debug + decoder_code
    
    # Additional obfuscation layer: Split and encode with ROT13
    combined_rot13 = _rot13(combined_code)
    combined_encoded = base64.b64encode(combined_rot13.encode("utf-8")).decode("ascii")
    
    # Final layer: Create wrapper with advanced obfuscation techniques
    wrapper_var = _generate_random_var_name()
    eval_var = _generate_random_var_name()
    rot13_decode_var = _generate_random_var_name()
    atob_var = _generate_random_var_name()
    temp_var = _generate_random_var_name()
    
    # Create obfuscated decoder with ROT13 reverse
    final_wrapper = f"""
(function(){{
    var {wrapper_var}='{combined_encoded}';
    var {atob_var}=function(_){{var _1=window.atob||function(_2){{var _3='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';var _4='',_5='',_6='',_7='',_8='',_9='',_a='',_b='';_2=String(_2).replace(/[^A-Za-z0-9\\+\\/\\=]/g,'');for(var _c=0;_c<_2.length;){{_7=_3.indexOf(_2.charAt(_c++));_8=_3.indexOf(_2.charAt(_c++));_9=_3.indexOf(_2.charAt(_c++));_a=_3.indexOf(_2.charAt(_c++));_b=(_7<<2)|(_8>>4);_6=(_8&15)<<4|(_9>>2);_c=((_9&3)<<6)|_a;_4+=String.fromCharCode(_b);if(_9!=64){{_4+=String.fromCharCode(_6);}}if(_a!=64){{_4+=String.fromCharCode(_c);}}_b=_6=_c='';_7=_8=_9=_a='';}}return _4.replace(/\\0+$/,'');}};return _1(_);}};
    var {rot13_decode_var}=function(_){{var _1='';for(var _2=0;_2<_.length;_2++){{var _3=_[_2];if('a'<=_3&&_3<='z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-97+13)%%26+97);}}else if('A'<=_3&&_3<='Z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-65+13)%%26+65);}}else{{_1+=_3;}}}}return _1;}};
    var {temp_var}={atob_var}({wrapper_var});
    var {eval_var}=function(_){{try{{(0,eval)(_);}}catch(_e){{setTimeout(function(){{{eval_var}(_);}},10);}}}};
    {eval_var}({rot13_decode_var}({temp_var}));
}})();
"""
    
    # One more layer: base64 encode the entire wrapper again
    final_encoded_wrapper = base64.b64encode(final_wrapper.encode("utf-8")).decode("ascii")
    
    ultimate_var = _generate_random_var_name()
    ultimate_exec = _generate_random_var_name()
    ultimate_atob = _generate_random_var_name()
    
    ultimate_wrapper = f"""
(function(){{
    var {ultimate_var}='{final_encoded_wrapper}';
    var {ultimate_atob}=function(_){{return atob(_);}};
    var {ultimate_exec}=function(_){{eval(_);}};
    {ultimate_exec}({ultimate_atob}({ultimate_var}));
}})();
"""
    
    return ultimate_wrapper


def obfuscate_html(html_text: str) -> str:
    """Advanced multi-layer HTML encryption"""
    # Layer 1: Split HTML into chunks
    chunks = _split_into_chunks(html_text, 100, 500)
    
    # Layer 2: Encode each chunk with base64 + ROT13 alternating pattern
    encoded_chunks = []
    
    for i, chunk in enumerate(chunks):
        # Alternate encoding methods for complexity
        if i % 2 == 0:
            # Base64 only
            encoded = base64.b64encode(chunk.encode("utf-8")).decode("ascii")
            encoded_chunks.append(encoded)
        else:
            # Base64 + ROT13
            rot13_chunk = _rot13(chunk)
            encoded = base64.b64encode(rot13_chunk.encode("utf-8")).decode("ascii")
            encoded_chunks.append(encoded)
    
    # Layer 3: Create decoder that reassembles chunks
    chunks_var = _generate_random_var_name()
    decoder_var = _generate_random_var_name()
    rot13_func_var = _generate_random_var_name()
    result_var = _generate_random_var_name()
    write_var = _generate_random_var_name()
    chunk_idx_var = _generate_random_var_name()
    
    chunks_json = '[' + ','.join(repr(c) for c in encoded_chunks) + ']'
    
    # Create ROT13 decoder function
    rot13_decoder = f"""
    var {rot13_func_var}=function(_){{var _1='';for(var _2=0;_2<_.length;_2++){{var _3=_[_2];if('a'<=_3&&_3<='z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-97+13)%%26+97);}}else if('A'<=_3&&_3<='Z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-65+13)%%26+65);}}else{{_1+=_3;}}}}return _1;}};
    """
    
    decoder_code = f"""
(function(){{
    var {chunks_var}={chunks_json};
    var {decoder_var}=function(_){{var _1=window.atob||function(_2){{var _3='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';var _4='',_5='',_6='',_7='',_8='',_9='',_a='',_b='';_2=String(_2).replace(/[^A-Za-z0-9\\+\\/\\=]/g,'');for(var _c=0;_c<_2.length;){{_7=_3.indexOf(_2.charAt(_c++));_8=_3.indexOf(_2.charAt(_c++));_9=_3.indexOf(_2.charAt(_c++));_a=_3.indexOf(_2.charAt(_c++));_b=(_7<<2)|(_8>>4);_6=(_8&15)<<4|(_9>>2);_c=((_9&3)<<6)|_a;_4+=String.fromCharCode(_b);if(_9!=64){{_4+=String.fromCharCode(_6);}}if(_a!=64){{_4+=String.fromCharCode(_c);}}_b=_6=_c='';_7=_8=_9=_a='';}}return _4.replace(/\\0+$/,'');}};return _1(_);}};
    {rot13_decoder}
    var {result_var}='';
    var {write_var}=function(_){{document.open();document.write(_);document.close();}};
    for(var {chunk_idx_var}=0;{chunk_idx_var}<{chunks_var}.length;{chunk_idx_var}++){{
        var _decoded={decoder_var}({chunks_var}[{chunk_idx_var}]);
        if({chunk_idx_var}%%2===1){{_decoded={rot13_func_var}(_decoded);}}
        {result_var}+=_decoded;
    }}
    try{{{write_var}({result_var});}}catch(_e){{setTimeout(function(){{{write_var}({result_var});}},100);}}
}})();
"""
    
    # Add anti-debugging
    checksum = sum(ord(c) for c in html_text) % 10000
    anti_debug = _ANTI_DEBUG_CODE.replace('%CHECKSUM%', str(checksum))
    
    # Final obfuscation - multiple layers
    # Layer 4: Encode decoder with base64 + ROT13
    layer4 = _rot13(decoder_code)
    layer4_encoded = base64.b64encode(layer4.encode("utf-8")).decode("ascii")
    
    # Layer 5: Combine anti-debug and decoder
    combined = anti_debug + f"(function(){{var _d=atob('{layer4_encoded}');var _r=function(_){{var _1='';for(var _2=0;_2<_.length;_2++){{var _3=_[_2];if('a'<=_3&&_3<='z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-97+13)%%26+97);}}else if('A'<=_3&&_3<='Z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-65+13)%%26+65);}}else{{_1+=_3;}}}}return _1;}};(0,eval)(_r(_d));}})();"
    
    # Layer 6: Final base64 encoding
    final_encoded = base64.b64encode(combined.encode("utf-8")).decode("ascii")
    
    wrapper_var = _generate_random_var_name()
    exec_var = _generate_random_var_name()
    eval_var = _generate_random_var_name()
    
    final_html = f"""<!doctype html><html><head><meta charset="utf-8"><title></title></head><body><script>
(function(){{
    var {wrapper_var}='{final_encoded}';
    var {exec_var}=function(_){{
        var _1=atob(_);
        var {eval_var}=function(_2){{(0,eval)(_2);}};
        {eval_var}(_1);
    }};
    try{{{exec_var}({wrapper_var});}}catch(_e){{setTimeout(function(){{{exec_var}({wrapper_var});}},50);}}
}})();
</script></body></html>"""
    
    return final_html


def obfuscate_css(css_text: str) -> str:
    """Advanced CSS obfuscation with multiple layers"""
    # Minify and obfuscate CSS
    # Remove comments
    css = re.sub(r'/\*.*?\*/', '', css_text, flags=re.DOTALL)
    # Remove extra whitespace
    css = re.sub(r'\s+', ' ', css)
    css = css.strip()
    
    # Layer 1: Base64 encode
    layer1 = base64.b64encode(css.encode("utf-8")).decode("ascii")
    
    # Layer 2: ROT13
    layer2 = _rot13(layer1)
    
    # Layer 3: Base64 again
    layer3 = base64.b64encode(layer2.encode("utf-8")).decode("ascii")
    
    # Generate random variable names
    var_style = _generate_random_var_name()
    var_atob1 = _generate_random_var_name()
    var_atob2 = _generate_random_var_name()
    var_rot13 = _generate_random_var_name()
    var_inject = _generate_random_var_name()
    var_head = _generate_random_var_name()
    var_elem = _generate_random_var_name()
    
    # Add dead code
    dead_code = _generate_dead_code(random.randint(3, 6))
    
    # Create obfuscated style injector with multiple decoding layers
    obfuscated = f"""
(function(){{
    {dead_code}
    var {var_style}='{layer3}';
    var {var_atob1}=function(_){{var _1=window.atob||function(_2){{var _3='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';var _4='',_5='',_6='',_7='',_8='',_9='',_a='',_b='';_2=String(_2).replace(/[^A-Za-z0-9\\+\\/\\=]/g,'');for(var _c=0;_c<_2.length;){{_7=_3.indexOf(_2.charAt(_c++));_8=_3.indexOf(_2.charAt(_c++));_9=_3.indexOf(_2.charAt(_c++));_a=_3.indexOf(_2.charAt(_c++));_b=(_7<<2)|(_8>>4);_6=(_8&15)<<4|(_9>>2);_c=((_9&3)<<6)|_a;_4+=String.fromCharCode(_b);if(_9!=64){{_4+=String.fromCharCode(_6);}}if(_a!=64){{_4+=String.fromCharCode(_c);}}_b=_6=_c='';_7=_8=_9=_a='';}}return _4.replace(/\\0+$/,'');}};return _1(_);}};
    var {var_atob2}=function(_){{return {var_atob1}(_);}};
    var {var_rot13}=function(_){{var _1='';for(var _2=0;_2<_.length;_2++){{var _3=_[_2];if('a'<=_3&&_3<='z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-97+13)%%26+97);}}else if('A'<=_3&&_3<='Z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-65+13)%%26+65);}}else{{_1+=_3;}}}}return _1;}};
    var {var_elem}=document.createElement('style');
    var {var_head}=document.head||document.getElementsByTagName('head')[0];
    var {var_inject}=function(_){{
        {var_elem}.innerHTML=_;
        {var_head}.appendChild({var_elem});
    }};
    var _decoded1={var_atob2}({var_style});
    var _decoded2={var_rot13}(_decoded1);
    var _final={var_atob1}(_decoded2);
    {var_inject}(_final);
}})();
"""
    
    # Triple encode with ROT13
    obf_rot13 = _rot13(obfuscated)
    final_encoded1 = base64.b64encode(obf_rot13.encode("utf-8")).decode("ascii")
    final_encoded2 = base64.b64encode(final_encoded1.encode("utf-8")).decode("ascii")
    
    # Final wrapper
    wrapper_var = _generate_random_var_name()
    exec_var = _generate_random_var_name()
    rot13_final = _generate_random_var_name()
    atob_final = _generate_random_var_name()
    
    final_wrapper = f"""<script>
(function(){{
    var {wrapper_var}='{final_encoded2}';
    var {atob_final}=function(_){{return atob(_);}};
    var {rot13_final}=function(_){{var _1='';for(var _2=0;_2<_.length;_2++){{var _3=_[_2];if('a'<=_3&&_3<='z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-97+13)%%26+97);}}else if('A'<=_3&&_3<='Z'){{_1+=String.fromCharCode((_3.charCodeAt(0)-65+13)%%26+65);}}else{{_1+=_3;}}}}return _1;}};
    var {exec_var}=function(_){{eval(_);}};
    var _d1={atob_final}({wrapper_var});
    var _d2={atob_final}(_d1);
    {exec_var}({rot13_final}(_d2));
}})();
</script>"""
    
    return final_wrapper


def compile_project(project_root: str, out_path: str) -> None:
    excluded_dirs: Set[str] = {".git", "__pycache__"}
    excluded_files = {os.path.abspath(out_path)}

    with tempfile.TemporaryDirectory(prefix="byhunide_build_") as tmp:
        tmp_root = os.path.join(tmp, "project")
        os.makedirs(tmp_root, exist_ok=True)

        for root, dirs, files in os.walk(project_root):
            dirs[:] = [d for d in dirs if d not in excluded_dirs]
            for fn in files:
                src = os.path.join(root, fn)
                if os.path.abspath(src) in excluded_files:
                    continue

                rel = os.path.relpath(src, project_root)
                dst = os.path.join(tmp_root, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)

                _, ext = os.path.splitext(src)
                ext = ext.lower()

                if ext in {".html", ".js", ".css"}:
                    with open(src, "r", encoding="utf-8", errors="replace") as f:
                        text = f.read()
                    if ext == ".js":
                        out_text = obfuscate_js(text)
                    elif ext == ".html":
                        out_text = obfuscate_html(text)
                    elif ext == ".css":
                        out_text = obfuscate_css(text)
                    else:
                        out_text = text
                    with open(dst, "w", encoding="utf-8") as f:
                        f.write(out_text)
                else:
                    with open(src, "rb") as fsrc:
                        data = fsrc.read()
                    with open(dst, "wb") as fdst:
                        fdst.write(data)

        if not out_path.lower().endswith(".zip"):
            out_path += ".zip"

        with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for root, _, files in os.walk(tmp_root):
                for fn in files:
                    full = os.path.join(root, fn)
                    rel = os.path.relpath(full, tmp_root)
                    zf.write(full, rel)
