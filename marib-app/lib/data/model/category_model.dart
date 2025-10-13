// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:marib/utils/api.dart';

class Type {
  String? id;
  String? type;

  Type({this.id, this.type});

  Type.fromJson(Map<String, dynamic> json) {
    id = json[Api.id].toString();
    type = json[Api.type];
  }
}

class CategoryModel {
  final int? id;
  final String? name;
  final String? url;
  final List<CategoryModel>? children;
  final String? description;
  final String? interfaceType;

  //final String translatedName;
  final int? subcategoriesCount;

  CategoryModel({
    this.id,
    this.name,
    this.url,
    this.description,
    this.children,
    this.interfaceType,
    this.subcategoriesCount,
    //required this.translatedName,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    try {
      List<dynamic> childData = json['subcategories'] ?? [];
      List<CategoryModel> children = childData
          .whereType<Map<String, dynamic>>()
          .map((child) => CategoryModel.fromJson(child))
          .toList();

      return CategoryModel(
          id: _parseId(json['id']),
          //name: json['name'],
          name: json['translated_name'] ?? json['name'],
          url: json['image'],
          subcategoriesCount: json['subcategories_count'] ?? children.length,
          children: children,
          description: json['description'] ?? "",
          interfaceType: _parseInterfaceType(json));
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      //'name': name,
      'translated_name': name,
      'image': url,
      'subcategories_count': subcategoriesCount,
      "description": description,
      'interface_type': interfaceType,
      'subcategories': (children ?? const <CategoryModel>[])
          .map((child) => child.toJson())
          .toList(),
    };
    return data;
  }

  @override
  String toString() {
    return 'CategoryModel( id: $id, translated_name:$name, url: $url, descrtiption:$description, interfaceType:$interfaceType, children: $children,subcategories_count:$subcategoriesCount)';
  }

  static int? _parseId(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static String? _parseInterfaceType(Map<String, dynamic> json) {
    final dynamic value = json['interface_type'] ?? json['interfaceType'];
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }
}
