import 'package:flutter/material.dart';

/// 名片数据模型 - 按照PRD V1.0定义（扩展版）
class BusinessCard {
  final String id;
  final String name;          // 必填
  final String? company;
  final String? department;
  final String? title;
  final String? tel;
  final String? mobile;
  final String? fax;
  final String? phone;        // 向后兼容
  final String? email;
  final String? address;
  final String? website;
  final String? notes;
  final List<String> imageUrls;     // 多张原始名片图片路径
  final Map<String, String> socialAccounts; // 社交媒体账号
  bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessCard({
    required this.id,
    required this.name,
    this.company,
    this.department,
    this.title,
    this.tel,
    this.mobile,
    this.fax,
    this.phone,
    this.email,
    this.address,
    this.website,
    this.notes,
    List<String>? imageUrls,
    Map<String, String>? socialAccounts,
    this.isFavorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : imageUrls = imageUrls ?? [],
       socialAccounts = socialAccounts ?? {},
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 复制并更新
  BusinessCard copyWith({
    String? name,
    String? company,
    String? department,
    String? title,
    String? tel,
    String? mobile,
    String? fax,
    String? phone,
    String? email,
    String? address,
    String? website,
    String? notes,
    List<String>? imageUrls,
    Map<String, String>? socialAccounts,
    bool? isFavorite,
  }) {
    return BusinessCard(
      id: id,
      name: name ?? this.name,
      company: company ?? this.company,
      department: department ?? this.department,
      title: title ?? this.title,
      tel: tel ?? this.tel,
      mobile: mobile ?? this.mobile,
      fax: fax ?? this.fax,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      imageUrls: imageUrls ?? this.imageUrls,
      socialAccounts: socialAccounts ?? this.socialAccounts,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 搜索匹配（姓名/公司/电话/邮箱/部门）
  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
           (company?.toLowerCase().contains(q) ?? false) ||
           (department?.toLowerCase().contains(q) ?? false) ||
           (phone?.contains(q) ?? false) ||
           (tel?.contains(q) ?? false) ||
           (mobile?.contains(q) ?? false) ||
           (email?.toLowerCase().contains(q) ?? false);
  }

  /// 获取显示用的电话号码（优先tel，其次phone，其次mobile）
  String? get displayPhone => tel ?? phone ?? mobile;

  /// 转换为 Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'department': department,
      'title': title,
      'tel': tel,
      'mobile': mobile,
      'fax': fax,
      'phone': phone,
      'email': email,
      'address': address,
      'website': website,
      'notes': notes,
      'imageUrls': imageUrls,
      'socialAccounts': socialAccounts,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 从 Map 创建
  factory BusinessCard.fromJson(Map<String, dynamic> json) {
    return BusinessCard(
      id: json['id'] as String,
      name: json['name'] as String,
      company: json['company'] as String?,
      department: json['department'] as String?,
      title: json['title'] as String?,
      tel: json['tel'] as String?,
      mobile: json['mobile'] as String?,
      fax: json['fax'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      notes: json['notes'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      socialAccounts: (json['socialAccounts'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 获取所有联系信息的文本（用于复制到剪贴板）
  String toContactText() {
    final buffer = StringBuffer();
    buffer.writeln(name);
    if (company != null) buffer.writeln('Company: $company');
    if (department != null) buffer.writeln('Department: $department');
    if (title != null) buffer.writeln('Title: $title');
    if (tel != null) buffer.writeln('TEL: $tel');
    if (mobile != null) buffer.writeln('Mobile: $mobile');
    if (fax != null) buffer.writeln('Fax: $fax');
    if (phone != null && phone != tel && phone != mobile) buffer.writeln('Phone: $phone');
    if (email != null) buffer.writeln('Email: $email');
    if (address != null) buffer.writeln('Address: $address');
    if (website != null) buffer.writeln('Website: $website');
    if (notes != null) buffer.writeln('Notes: $notes');
    return buffer.toString().trim();
  }
}

/// 我的数字名片
class MyDigitalCard {
  String name;
  String? company;
  String? department;
  String? title;
  String? phone;
  String? email;
  String? website;

  MyDigitalCard({
    required this.name,
    this.company,
    this.department,
    this.title,
    this.phone,
    this.email,
    this.website,
  });
}

/// Mock数据 - 用于开发测试
class MockData {
  static final List<BusinessCard> recentCards = [
    BusinessCard(
      id: '1',
      name: '张伟',
      company: '阿里巴巴集团',
      department: '产品部',
      title: '高级产品经理',
      tel: '021-6688-1234',
      mobile: '138-0000-1234',
      phone: '138-0000-1234',
      email: 'zhangwei@alibaba.com',
      address: '杭州市余杭区文一西路969号',
      website: 'www.alibaba.com',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    BusinessCard(
      id: '2',
      name: 'Sarah Chen',
      company: 'Microsoft',
      department: 'Engineering',
      title: 'Software Engineer',
      tel: '+1 425-882-8080',
      mobile: '+1 555-123-4567',
      phone: '+1 555-123-4567',
      email: 'sarah.chen@microsoft.com',
      address: 'One Microsoft Way, Redmond, WA',
      website: 'www.microsoft.com',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    BusinessCard(
      id: '3',
      name: '田中太郎',
      company: 'トヨタ自動車',
      department: '営業部',
      title: '営業部長',
      tel: '03-1234-5678',
      mobile: '090-1234-5678',
      phone: '090-1234-5678',
      email: 'tanaka@toyota.co.jp',
      address: '愛知県豊田市トヨタ町1番地',
      website: 'www.toyota.co.jp',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    BusinessCard(
      id: '4',
      name: '李明',
      company: '华为技术有限公司',
      department: '研发部',
      title: '技术总监',
      tel: '0755-2888-8888',
      mobile: '139-8888-9999',
      phone: '139-8888-9999',
      email: 'liming@huawei.com',
      address: '深圳市龙岗区坂田华为基地',
      website: 'www.huawei.com',
      isFavorite: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    BusinessCard(
      id: '5',
      name: 'John Smith',
      company: 'Google',
      department: 'Product',
      title: 'Product Lead',
      tel: '+1 650-253-0000',
      mobile: '+1 650-555-0100',
      phone: '+1 650-555-0100',
      email: 'jsmith@google.com',
      address: '1600 Amphitheatre Parkway, Mountain View, CA',
      website: 'www.google.com',
      isFavorite: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  static final MyDigitalCard myCard = MyDigitalCard(
    name: 'Simon Xie',
    company: 'TOPPAN Group',
    department: 'Sales',
    title: 'Sales Director',
    phone: '+86 138-0000-0000',
    email: 'simon@toppan.com',
    website: 'www.toppan.com',
  );
}
