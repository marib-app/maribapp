<?php

namespace App\Http\Controllers;

class RequestDeviceController extends SectionedRequestDeviceController

{
    public function __construct()

    {
        $this->section = 'computer';
        $this->indexPermission = 'computer-requests-list';
        $this->deletePermission = 'computer-requests-delete';
        $this->indexRouteName = 'item.computer.custom-orders.index';
        $this->showRouteName = 'item.computer.custom-orders.show';
        $this->destroyRouteName = 'item.computer.custom-orders.destroy';
        $this->viewNamespace = 'computer_requests';
        $this->indexPageTitle = 'طلبات الكمبيوتر';
        $this->detailPageTitle = 'تفاصيل طلب الكمبيوتر';
    }
}