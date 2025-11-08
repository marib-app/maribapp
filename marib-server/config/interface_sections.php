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

$interfaceSectionRoots = [
    'homepage'    => null,
    'public'      => null,
    'request_ad'  => null,
    'real_estate' => 'real_estate_services',
    'tourism'     => 'tourism_services',
    'merchants'   => 'e_store',
    'shein'       => 'shein_products',
    'computer'    => 'computer_section',
];


$serviceSectionRoots = [
    'services_all' => array_values($serviceCategoryMap),
];

foreach ($serviceCategoryMap as $serviceKey => $categoryId) {
    $serviceSectionRoots[$serviceKey] = $categoryId;
}

$interfaceSectionRoots = array_merge($interfaceSectionRoots, $serviceSectionRoots);

return [
    'cache_ttl_seconds' => (int) env('FEATURE_SECTION_CACHE_TTL_SECONDS', 300),
    'section_item_limit' => (int) env('FEATURE_SECTION_ITEM_LIMIT', 12),
    'default_filters' => [
        'featured',
        'latest',
        'most_viewed',
        'price_range',
    ],
    'root_identifiers' => $interfaceSectionRoots,
    'allowed_section_types' => array_keys($interfaceSectionRoots),

    'section_type_aliases' => [
        'real_estate_services' => 'real_estate',
        'realestateservices'   => 'real_estate',
        'itemsListRealEstate'  => 'real_estate',
        'itemslistrealestate'  => 'real_estate',

        'tourism_services'     => 'tourism',
        'tourismservices'      => 'tourism',
        'itemsListTourism'     => 'tourism',
        'itemslisttourism'     => 'tourism',

        'e_store'              => 'merchants',
        'estore'               => 'merchants',
        'itemsListEStore'      => 'merchants',
        'itemslistestore'      => 'merchants',
        'itemsListMerchants'   => 'merchants',
        'itemslistmerchants'   => 'merchants',


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
        'home_page'            => 'homepage',
        'homepage_section'     => 'homepage',
        'itemsListHomepage'    => 'homepage',
        'itemslisthomepage'    => 'homepage',

        'request_ads'          => 'request_ad',
        'requestads'           => 'request_ad',
        'requestAd'            => 'request_ad',
        'itemsListRequestAd'   => 'request_ad',
        'itemslistrequestad'   => 'request_ad',


    ],
    'service_category_map' => $serviceCategoryMap,
];
