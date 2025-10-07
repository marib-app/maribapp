<?php

namespace App\Http\Controllers;

class SheinRequestController extends SectionedRequestDeviceController
{
    public function __construct()
    {
        $this->section = 'shein';
        $this->indexPermission = 'shein-requests-list';
        $this->deletePermission = 'shein-requests-delete';
        $this->indexRouteName = 'item.shein.custom-orders.index';
        $this->showRouteName = 'item.shein.custom-orders.show';
        $this->destroyRouteName = 'item.shein.custom-orders.destroy';
        $this->viewNamespace = 'shein_requests';
        $this->indexPageTitle = 'طلبات شي إن الخاصة';
        $this->detailPageTitle = 'تفاصيل طلب شي إن الخاص';
    }
}