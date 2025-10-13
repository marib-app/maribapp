<?php


$serviceCategoryMap = [
    'services_local'         => (int) env('SERVICE_CATEGORY_LOCAL_ID', 174),
    'services_medical'       => (int) env('SERVICE_CATEGORY_MEDICAL_ID', 175),
    'services_jobs'          => (int) env('SERVICE_CATEGORY_JOBS_ID', 176),
    'services_events_offers' => (int) env('SERVICE_CATEGORY_EVENTS_OFFERS_ID', 114),
    'services_marib_lost'    => (int) env('SERVICE_CATEGORY_MARIB_LOST_ID', 181),
    'services_student'       => (int) env('SERVICE_CATEGORY_STUDENT_ID', 180),
    'services_marib_guide'   => (int) env('SERVICE_CATEGORY_MARIB_GUIDE_ID', 177),
];

$featureSectionRoots = [
    'public'      => null,
    'real_estate' => 'real_estate_services',
    'shein'       => null,
    'computer'    => 'computer_section',
];


return [
    'cache_ttl_seconds' => (int) env('FEATURE_SECTION_CACHE_TTL_SECONDS', 300),
    'section_item_limit' => (int) env('FEATURE_SECTION_ITEM_LIMIT', 12),
    'default_filters' => [
        'featured',
        'latest',
        'most_viewed',
        'price_range',
    ],
    'root_identifiers' => $featureSectionRoots,
    'allowed_section_types' => array_keys($featureSectionRoots),

    'section_type_aliases' => [
        'real_estate_services' => 'real_estate',
        'realestateservices'   => 'real_estate',
        'itemsListRealEstate'  => 'real_estate',
        'itemslistrealestate'  => 'real_estate',


        'shein_products'       => 'shein',
        'sheinproducts'        => 'shein',
        'itemsListShein'       => 'shein',
        'itemslistshein'       => 'shein',

        'computer_section'     => 'computer',
        'computersection'      => 'computer',
        'itemsListComputer'    => 'computer',
        'itemslistcomputer'    => 'computer',

        'public_ads'           => 'public',
        'publicads'            => 'public',
        'itemsListPublic'      => 'public',
        'itemslistpublic'      => 'public',
        'homepage'             => 'public',
        'home_page'            => 'public',



    ],
    'service_category_map' => $serviceCategoryMap,
];