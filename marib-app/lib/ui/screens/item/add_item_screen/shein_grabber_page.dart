import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:marib/utils/ui_utils.dart';

class SheinGrabberPage extends StatefulWidget {
  final String startUrl;
  const SheinGrabberPage({super.key, required this.startUrl});

  @override
  State<SheinGrabberPage> createState() => _SheinGrabberPageState();
}

class _SheinGrabberPageState extends State<SheinGrabberPage> {
  InAppWebViewController? _ctrl;
  bool _extracting = false;
  double _progress = 0;

  final String _extractJs = r"""
(function(){
  function meta(sel){var m=document.querySelector(sel); return m?m.content:null}
  function abs(u){ if(!u) return null;
    if(u.startsWith('//')) return location.protocol + u;
    if(u.startsWith('/'))  return location.origin + u;
    return u;
  }
  function goodImg(u){
    if(!u) return false;
    u=u.toLowerCase();
    if(!/^https?:/.test(u)) return false;
    if(!/\.(jpg|jpeg|png|webp)(\?|$)/.test(u)) return false;
    return !/(sprite|logo|icon|placeholder|avatar|favicon|brand)/.test(u);
  }

  // =========== الأساسيات ===========
  let title = meta('meta[property="og:title"]') || document.title || null;
  let price = meta('meta[property="product:price:amount"]') || meta('meta[property="og:price:amount"]') || null;
  let currency = meta('meta[property="product:price:currency"]') || meta('meta[property="og:price:currency"]') || null;

  // الصور
  let images = new Set();
  let og = abs(meta('meta[property="og:image"]'));
  if(goodImg(og)) images.add(og);
  document.querySelectorAll('img').forEach(img=>{
    ['src','data-src','data-original','data-lazy','data-bg','data-image','data-zoom-image','data-bigimg','data-big'].forEach(k=>{
      let v=abs(img.getAttribute(k)); if(goodImg(v)) images.add(v);
    });
    let ss=img.getAttribute('srcset');
    if(ss){ ss.split(',').forEach(part=>{
      let u=abs(part.trim().split(' ')[0]); if(goodImg(u)) images.add(u);
    });}
  });

  // =========== مُساعدات JSON ===========
  function safeParse(txt){
    try { return JSON.parse(txt); } catch(e){ return null; }
  }
  function walkJSON(node, visitor){
    if(!node) return;
    if(Array.isArray(node)) { node.forEach(n=>walkJSON(n,visitor)); return; }
    if(typeof node === 'object') {
      visitor(node);
      Object.keys(node).forEach(k=>walkJSON(node[k], visitor));
    }
  }

  // لتجميع النتائج
  let properties = []; // [{name: 'Size', items:[{id,name,available}]} , {name:'Color', ...}]
  let variants = [];   // [{skuId, props:{Size:'M', Color:'Black'}, price, currency, stock}]
  let stockTotal = null;

  function pushProperty(name, arr){
    if(!name || !arr || !arr.length) return;
    // دمج إن كان موجود
    const ix = properties.findIndex(p=>p.name.toLowerCase()===String(name).toLowerCase());
    if(ix>=0){
      const seen = new Set(properties[ix].items.map(i=>i.id||i.name));
      arr.forEach(it=>{
        const key = it.id || it.name;
        if(key && !seen.has(key)) properties[ix].items.push(it);
      });
    }else{
      properties.push({name:String(name), items:arr});
    }
  }

  // يجرّب استخراج من JSON-LD أولاً
  document.querySelectorAll('script[type="application/ld+json"]').forEach(s=>{
    const data = safeParse(s.textContent.trim());
    if(!data) return;
    walkJSON(data, node=>{
      const t = (node['@type']||'').toString().toLowerCase();
      if(t==='product'){
        if(!title && node.name) title = node.name;
        if(node.offers){
          let o = node.offers;
          if(Array.isArray(o)) o = o[0] || {};
          price    = price    || (o.price!=null? String(o.price): null);
          currency = currency || (o.priceCurrency || null);
          // بعض الصفحات تعرض sku/variants هنا
          if(o.sku){ /* optional */ }
        }
        // أحياناً الصور هنا
        const im = node.image;
        if(im){
          (Array.isArray(im)? im : [im]).forEach(u=>{ u=abs(u); if(goodImg(u)) images.add(u); });
        }
      }
    });
  });

  // =========== اصطياد State داخلي ===========
  // ندور على سكربت يحتوي كلمات SKU مع JSON كبير
  const skuHints = /(sku[_-]?list|sku[_-]?info|skuPropertyList|skuMap|product_id|goods_id|stock|attribute|attrValList|saleAttr)/i;
  let bigJson = null;

  Array.from(document.querySelectorAll('script')).some(s=>{
    const txt = s.textContent || '';
    if(skuHints.test(txt) && txt.replace(/\s+/g,'').length > 5000){
      // حاول نطلع JSON متوازن من أول { إلى آخر } كبير
      const start = txt.indexOf('{');
      const end   = txt.lastIndexOf('}');
      if(start>=0 && end>start){
        const slice = txt.slice(start, end+1);
        const parsed = safeParse(slice);
        if(parsed){ bigJson = parsed; return true; }
      }
    }
    return false;
  });

  // دوال تكيّفية لاستخراج من هياكل مختلفة
  function extractFromCommonStructures(root){
    if(!root) return;

    // محاولات لإيجاد العملة إن لسا ما انوجدت
    if(!currency){
      let cands = [];
      walkJSON(root, n=>{
        if(typeof n.currency === 'string') cands.push(n.currency);
        if(typeof n.priceCurrency === 'string') cands.push(n.priceCurrency);
        if(n.money && n.money.currency) cands.push(n.money.currency);
      });
      if(cands.length) currency = cands[0];
    }

    // خصائص (مقاس/لون..)
    // أمثلة محتملة للأسماء: skuPropertyList, saleAttr, attributes, props, prop_list
    let propBuckets = [];
    walkJSON(root, n=>{
      const lists = [
        n.skuPropertyList,
        n.saleAttr,
        n.saleAttrs,
        n.attributes,
        n.props,
        n.prop_list
      ].filter(Boolean);

      lists.forEach(list=>{
        if(Array.isArray(list)){
          list.forEach(prop=>{
            const name = prop.name || prop.propName || prop.attrName || prop.title;
            const itemsRaw = prop.values || prop.attrValList || prop.valueList || prop.items || prop.attr_value_list;
            let items = [];
            if(Array.isArray(itemsRaw)){
              items = itemsRaw.map(v=>{
                const id = v.id || v.vid || v.valueId || v.attrId || v.skuId || null;
                const nm = v.name || v.value || v.attrValue || v.text || v.title || String(id||'').trim();
                const avail = v.available ?? v.enable ?? v.status ?? true;
                const color = v.color || v.rgb || v.hex || null;
                const img   = abs(v.imgUrl || v.image || v.img || null);
                return { id, name: nm, available: !!avail, color: color, image: img };
              }).filter(x=>x && x.name);
            }
            if(name && items.length){
              propBuckets.push({name, items});
            }
          });
        }
      });
    });
    propBuckets.forEach(p=>pushProperty(p.name, p.items));

    // الـVariants / SKUs
    let localVariants = [];
    walkJSON(root, n=>{
      const skuList = n.skuList || n.sku_list || n.skus || n.sku || null;
      if(Array.isArray(skuList)){
        skuList.forEach(s=>{
          const skuId = s.skuId || s.id || s.sku || s.goods_sku || null;
          const price = (s.price!=null ? String(s.price) :
                        (s.salePrice!=null ? String(s.salePrice) :
                        (s.activityPrice!=null ? String(s.activityPrice) : null)));
          const stock = s.stock != null ? Number(s.stock) :
                        (s.inventory != null ? Number(s.inventory) : null);
          // تجميع خصائص هذا المتغير
          let props = {};
          // أمثلة مفاتيح: propName/propValue, saleAttrs, attributes, specs...
          const pairs = s.saleAttrs || s.attributes || s.specs || s.props || s.properties;
          if(Array.isArray(pairs)){
            pairs.forEach(p=>{
              const k = p.name || p.propName || p.attrName || p.key;
              const v = p.value || p.attrValue || p.val || p.text || p.propValue;
              if(k && v) props[k]=v;
            });
          }
          // بعض الصفحات تجعل map مثل {Color:'Black', Size:'M'}
          if(!Object.keys(props).length && typeof s === 'object'){
            Object.keys(s).forEach(k=>{
              if(/size|color|尺码|颜色/i.test(k) && typeof s[k] === 'string'){
                props[k]=s[k];
              }
            });
          }

          localVariants.push({
            skuId: skuId,
            price: price,
            currency: currency || null,
            stock: stock,
            props: props
          });
        });
      }
      // مخازن شاملة
      if(n.stockTotal!=null && stockTotal==null) stockTotal = Number(n.stockTotal);
      if(n.totalStock!=null && stockTotal==null) stockTotal = Number(n.totalStock);
    });
    if(localVariants.length) variants = localVariants;
  }

  if(bigJson) extractFromCommonStructures(bigJson);

  // محاولة أخيرة: أحيانًا فيه state عالمي مثل __NUXT__ / __NEXT_DATA__ / g_config
  const win = window;
  const guesses = [win.__NUXT__, win.__NEXT_DATA__, win.g_config, win.g_page_config, win.__INITIAL_STATE__];
  guesses.forEach(g=>extractFromCommonStructures(g));

  // نتيجة نهائية
  return JSON.stringify({
    href: location.href,
    title: title || null,
    price: price || null,
    currency: currency || null,
    images: Array.from(images).slice(0,25),
    properties: properties,     // [{name, items:[{id,name,available,color?,image?}]}]
    variants: variants,         // [{skuId, price, currency, stock, props:{...}}]
    stockTotal: stockTotal
  });
})();
""";


  Future<void> _extract() async {
    if (_ctrl == null || _extracting) return;
    setState(() => _extracting = true);
    try {
      await Future.delayed(const Duration(seconds: 2)); // أمهل الـSPA
      final res = await _ctrl!.evaluateJavascript(source: _extractJs);
      final map = json.decode(res ?? '{}') as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.pop(context, map);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الاستخراج: $e')),
      );
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color scaffoldBackgroundColor = theme.scaffoldBackgroundColor;
    final Color appBarForegroundColor =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final SystemUiOverlayStyle overlay = UiUtils.getSystemUiOverlayStyle(
      context: context,
      statusBarColor: scaffoldBackgroundColor,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: scaffoldBackgroundColor,
        appBar: AppBar(
        systemOverlayStyle: overlay,
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: appBarForegroundColor,
        title: const Text('جلب منتج شي-إن'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: appBarForegroundColor,
            ),
            onPressed: _extracting ? null : _extract,
            child: _extracting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(appBarForegroundColor),
                    ),
                  )
                : const Text('استخراج'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0) LinearProgressIndicator(value: _progress),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.startUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                mediaPlaybackRequiresUserGesture: false,
                useOnLoadResource: true,
              ),
              onWebViewCreated: (c) => _ctrl = c,
              onLoadStop: (c, url) async {
                // هنا لو تحب تشغّل الاستخراج تلقائي
              },
              onProgressChanged: (c, p) => setState(() => _progress = p / 100),
            ),
          ),
        ],
      ),

      // ↓↓↓ زر الاستخراج يظهر فقط عند اكتمال التحميل
      floatingActionButton: (_progress >= 1.0)
          ? FloatingActionButton.extended(
        onPressed: _extracting ? null : _extract,
        icon: _extracting
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.download_for_offline),
        label: Text(_extracting ? 'جاري الاستخراج…' : 'استخراج'),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}
