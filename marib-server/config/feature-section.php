<?php


$serviceCategoryMap = [
    'services_local'        => (int) env('SERVICE_CATEGORY_LOCAL_ID', 174),
    'services_medical'      => (int) env('SERVICE_CATEGORY_MEDICAL_ID', 175),
    'services_jobs'         => (int) env('SERVICE_CATEGORY_JOBS_ID', 176),
    'services_events_offers'=> (int) env('SERVICE_CATEGORY_EVENTS_OFFERS_ID', 114),
    'services_marib_lost'   => (int) env('SERVICE_CATEGORY_MARIB_LOST_ID', 181),
    'services_student'      => (int) env('SERVICE_CATEGORY_STUDENT_ID', 180),
    'services_marib_guide'  => (int) env('SERVICE_CATEGORY_MARIB_GUIDE_ID', 177),
];

$serviceRootIdentifiers = [
    'services_all' => array_values($serviceCategoryMap),
];

foreach ($serviceCategoryMap as $type => $categoryId) {
    $serviceRootIdentifiers[$type] = $categoryId;
}

return [
    'cache_ttl_seconds' => (int) env('FEATURE_SECTION_CACHE_TTL_SECONDS', 300),
    'section_item_limit' => (int) env('FEATURE_SECTION_ITEM_LIMIT', 12),
    'default_filters' => [
        'latest',
        'most_viewed',
    ],
    'root_identifiers' => array_merge([
        'public'      => null,
        'real_estate' => 'real_estate_services',
        'tourism'     => 'tourism_services',
        'merchants'   => 'e_store',
        'shein'       => null,
        'computer'    => 'computer_section',
    ], $serviceRootIdentifiers),
    'allowed_section_types' => array_merge([


        'public',
        'real_estate',
        'tourism',
        'merchants',
        'shein',
        'computer',
    ], array_keys($serviceRootIdentifiers)),

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
        'itemsListSeller'      => 'merchants',
        'itemslistseller'      => 'merchants',

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

        'all_services'                 => 'services_all',
        'servicesall'                  => 'services_all',
        'services-all'                 => 'services_all',
        'itemsListServicesAll'         => 'services_all',
        'itemslistservicesall'         => 'services_all',

        'local_services'               => 'services_local',
        'localservices'                => 'services_local',
        'serviceslocal'                => 'services_local',
        'services-local'               => 'services_local',
        'itemsListServicesLocal'       => 'services_local',
        'itemslistserviceslocal'       => 'services_local',

        'medical_services'             => 'services_medical',
        'medicalservices'              => 'services_medical',
        'servicesmedical'              => 'services_medical',
        'services-medical'             => 'services_medical',
        'itemsListServicesMedical'     => 'services_medical',
        'itemslistservicesmedical'     => 'services_medical',

        'jobs_services'                => 'services_jobs',
        'jobsservices'                 => 'services_jobs',
        'servicesjobs'                 => 'services_jobs',
        'services-jobs'                => 'services_jobs',
        'itemsListServicesJobs'        => 'services_jobs',
        'itemslistservicesjobs'        => 'services_jobs',
        'jobs'                         => 'services_jobs',

        'events_offers_services'       => 'services_events_offers',
        'eventsoffersservices'         => 'services_events_offers',
        'servicesevents_offers'        => 'services_events_offers',
        'serviceseventsoffers'         => 'services_events_offers',
        'services-events-offers'       => 'services_events_offers',
        'itemsListServicesEventsOffers'=> 'services_events_offers',
        'itemslistserviceseventsoffers'=> 'services_events_offers',

        'marib_lost_services'          => 'services_marib_lost',
        'mariblostservices'            => 'services_marib_lost',
        'servicesmarib_lost'           => 'services_marib_lost',
        'servicesmariblost'            => 'services_marib_lost',
        'services-marib-lost'          => 'services_marib_lost',
        'itemsListServicesMaribLost'   => 'services_marib_lost',
        'itemslistservicesmariblost'   => 'services_marib_lost',

        'student_services'             => 'services_student',
        'studentservices'              => 'services_student',
        'servicesstudent'              => 'services_student',
        'services-student'             => 'services_student',
        'itemsListServicesStudent'     => 'services_student',
        'itemslistservicesstudent'     => 'services_student',

        'marib_guide_services'         => 'services_marib_guide',
        'maribguideservices'           => 'services_marib_guide',
        'servicesmarib_guide'          => 'services_marib_guide',
        'servicesmaribguide'           => 'services_marib_guide',
        'services-marib-guide'         => 'services_marib_guide',
        'itemsListServicesMaribGuide'  => 'services_marib_guide',
        'itemslistservicesmaribguide'  => 'services_marib_guide',



    ],
    'service_category_map' => $serviceCategoryMap,
];