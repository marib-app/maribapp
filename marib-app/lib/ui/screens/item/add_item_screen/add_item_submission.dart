library add_item_submission_service;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_model.dart';
import 'package:marib/ui/screens/user_profile/my_item_tab.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/geo_rules.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/ecommerce_department.dart';
import 'package:marib/ui/screens/item/purchase_options/pending_item_draft.dart';

part 'add_item_submission_part.dart';
