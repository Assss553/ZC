// cwconv: CodeWalker XML <-> GTA V binary resources (uses CodeWalker.Core)
//   cwconv import <file.ydr.xml|.ytd.xml|.ytyp.xml|.ybn.xml> <outfile>
//   cwconv export <file.ydr|.ytd|.ytyp|.ybn> <outfolder>     (round-trip check, writes XML + dds)
//   cwconv info   <file.ydr|.ytd|.ytyp>
using System;
using System.IO;
using System.Linq;
using System.Xml;
using CodeWalker.GameFiles;

static class Program
{
    static int Main(string[] args)
    {
        if (args.Length < 2) { Console.Error.WriteLine("usage: cwconv import|export|info <in> [out]"); return 2; }
        try
        {
            switch (args[0])
            {
                case "import": return Import(args[1], args[2]);
                case "export": return Export(args[1], args[2]);
                case "info": return Info(args[1]);
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("ERROR: " + ex);
            return 1;
        }
        return 2;
    }

    static int Import(string xmlPath, string outPath)
    {
        var doc = new XmlDocument();
        doc.Load(xmlPath);
        var fname = Path.GetFileName(xmlPath).ToLowerInvariant();
        var mformat = XmlMeta.GetXMLFormat(fname, out int trimlength);
        var folder = Path.GetDirectoryName(Path.GetFullPath(xmlPath));
        var data = XmlMeta.GetData(doc, mformat, folder);
        if (data == null) { Console.Error.WriteLine("ERROR: conversion returned no data for " + xmlPath); return 1; }
        File.WriteAllBytes(outPath, data);
        Console.WriteLine($"OK {mformat} {Path.GetFileName(outPath)} {data.Length} bytes");
        return 0;
    }

    static (RpfResourceFileEntry, byte[]) Load(string path)
    {
        var data = File.ReadAllBytes(path);
        var entry = RpfFile.CreateResourceFileEntry(ref data, 0);
        entry.Name = Path.GetFileName(path);
        entry.NameLower = entry.Name.ToLowerInvariant();
        data = ResourceBuilder.Decompress(data);
        return (entry, data);
    }

    static int Export(string binPath, string outFolder)
    {
        Directory.CreateDirectory(outFolder);
        var (entry, data) = Load(binPath);
        var xml = MetaXml.GetXml(entry, data, out string filename, outFolder);
        if (string.IsNullOrEmpty(xml)) { Console.Error.WriteLine("ERROR: could not export " + binPath); return 1; }
        File.WriteAllText(Path.Combine(outFolder, filename), xml);
        Console.WriteLine($"OK exported {filename} ({xml.Length} chars)");
        return 0;
    }

    static int Info(string binPath)
    {
        var (entry, data) = Load(binPath);
        var n = entry.NameLower;
        Console.WriteLine($"{entry.Name}: version {entry.Version}, system {entry.SystemSize} bytes, graphics {entry.GraphicsSize} bytes");
        if (n.EndsWith(".ydr"))
        {
            var ydr = RpfFile.GetFile<YdrFile>(entry, data);
            var d = ydr.Drawable;
            Console.WriteLine($"  drawable '{d.Name}' bbox {d.BoundingBoxMin} .. {d.BoundingBoxMax} radius {d.BoundingSphereRadius}");
            var shaders = d.ShaderGroup?.Shaders?.data_items;
            Console.WriteLine($"  shaders: {shaders?.Length ?? 0}, embedded textures: {d.ShaderGroup?.TextureDictionary?.Textures?.data_items?.Length ?? 0}");
            int verts = 0, tris = 0, geoms = 0;
            foreach (var m in d.AllModels ?? new DrawableModel[0])
                foreach (var g in m.Geometries ?? new DrawableGeometry[0])
                { geoms++; verts += g.VerticesCount; tris += (int)(g.IndicesCount / 3); }
            Console.WriteLine($"  geometries: {geoms}, vertices: {verts}, triangles: {tris}");
            Console.WriteLine($"  lights: {d.LightAttributes?.data_items?.Length ?? 0}");
            if (d.Bound is BoundComposite bc)
            {
                var ch = bc.Children?.data_items ?? new Bounds[0];
                Console.WriteLine($"  bound: composite with {ch.Length} children");
                foreach (var c in ch)
                {
                    if (c is BoundGeometry bg) Console.WriteLine($"    {c.Type}: {bg.Vertices?.Length ?? 0} verts, {bg.Polygons?.Length ?? 0} polys, {bg.Materials?.Length ?? 0} materials");
                    else Console.WriteLine($"    {c?.Type}");
                }
            }
            else Console.WriteLine($"  bound: {(d.Bound == null ? "none" : d.Bound.Type.ToString())}");
        }
        else if (n.EndsWith(".ytd"))
        {
            var ytd = RpfFile.GetFile<YtdFile>(entry, data);
            var texs = ytd.TextureDict?.Textures?.data_items ?? new Texture[0];
            Console.WriteLine($"  textures: {texs.Length}");
            foreach (var t in texs) Console.WriteLine($"    {t.Name} {t.Width}x{t.Height} mips {t.Levels} {t.Format}");
        }
        else if (n.EndsWith(".ytyp"))
        {
            var ytyp = RpfFile.GetFile<YtypFile>(entry, data);
            Console.WriteLine($"  archetypes: {ytyp.AllArchetypes?.Length ?? 0}");
            foreach (var a in ytyp.AllArchetypes ?? new Archetype[0])
                Console.WriteLine($"    {a.Name} txd={a._BaseArchetypeDef.textureDictionary} lod={a.LodDist} bb {a.BBMin} .. {a.BBMax} flags={a._BaseArchetypeDef.flags}");
        }
        return 0;
    }
}
