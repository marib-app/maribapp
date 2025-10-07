<?php

namespace App\Services;

class BootstrapTableService {
    private static string $defaultClasses = "btn icon btn-xs btn-rounded btn-icon rounded-pill";

    /**
     * @param string $iconClass
     * @param string $url
     * @param array $customClass
     * @param array $customAttributes
     * @param string $iconText
     * @return string
     */
    public static function button(string $iconClass, string $url, array $customClass = [], array $customAttributes = [], string $iconText = '') {
        $defaultClasses = array_filter(array_map('trim', explode(' ', self::$defaultClasses)));
        $customClasses = array_filter(array_map('trim', $customClass));

        if (trim($iconText) !== '') {
            $defaultClasses[] = 'btn-with-label';
        }

        $class = implode(' ', array_unique(array_merge($defaultClasses, $customClasses)));


        $attributes = '';
        if (count($customAttributes) > 0) {
            foreach ($customAttributes as $key => $value) {
                if ($value === null) {
                    continue;
                }

                $attributes .= $key . '="' . e($value) . '" ';
            
            }
        }
        $labelHtml = '';
        $iconLabel = trim($iconText);
        if ($iconLabel !== '') {
            $labelHtml = '<span class="btn-label">' . e($iconLabel) . '</span>';
        }

        return '<a href="' . e($url) . '" class="' . e($class) . '" ' . trim($attributes) . '><i class="' . e($iconClass) . '" aria-hidden="true"></i>' . $labelHtml . '</a>&nbsp;&nbsp;';
    
    }


    public static function dropdown(
    string $iconClass,
    array $dropdownItems,
    array $customClass = [],
    array $customAttributes = []
) {
    $customClassStr = implode(" ", $customClass);
    $class = self::$defaultClasses . ' dropdown ' . $customClassStr;
    $attributes = '';

    if (count($customAttributes) > 0) {
        foreach ($customAttributes as $key => $value) {
            $attributes .= $key . '="' . $value . '" ';
        }
    }

    $dropdown = '<div class="' . $class . '" ' . $attributes . '>';
    $dropdown .= '<button class="btn btn-secondary dropdown-toggle" type="button" id="dropdownMenuButton" data-bs-toggle="dropdown" aria-expanded="false">';
    $dropdown .= '<i class="' . $iconClass . '"></i>'; // Use the icon class here
    $dropdown .= '</button>';
    $dropdown .= '<ul class="dropdown-menu" aria-labelledby="dropdownMenuButton">';

    foreach ($dropdownItems as $item) {
        $dropdown .= '<li><a class="dropdown-item" href="' . $item['url'] . '"><i class="' . $item['icon'] . '"></i> ' . $item['text'] . '</a></li>';
    }

    $dropdown .= '</ul>';
    $dropdown .= '</div>';

    return $dropdown;
}



    /**
     * @param $url
     * @param bool $modal
     * @param string $dataBsTarget
     * @param null $customClass
     * @param null $id
     * @param string $iconClass
     * @param null $onClick
     * @return string
     */
    public static function editButton($url, bool $modal = false, $dataBsTarget = "#editModal", $customClass = null, $id = null, $iconClass = "fa fa-edit", $onClick = null, string $iconText = '') {


        $customClass = ["btn-primary" . " " . $customClass];
        $title = $iconText !== '' ? $iconText : trans('Edit');


        $customAttributes = [
            "title" => $title
        ];
        if ($modal) {
            $customAttributes = [
                "title"          => $title,
                "data-bs-target" => $dataBsTarget,
                "data-bs-toggle" => "modal",
                "id"             => $id,
                "onclick"        => $onClick,
            ];

            $customClass[] = "edit_btn set-form-url";
        }
        return self::button($iconClass, $url, $customClass, $customAttributes, $iconText);
    }

    /**
     * @param $url
     * @param null $id
     * @param null $dataId
     * @param null $dataCategory
     * @param null $customClass
     * @return string
     */
    public static function deleteButton($url, $id = null, $dataId = null, $dataCategory = null, $customClass = null, string $iconText = '') {
        $customClass = ["delete-form", "btn-danger" . $customClass];
        $customAttributes = [
            "title"         => $iconText !== '' ? $iconText : trans("Delete"),
            "id"            => $id,
            "data-id"       => $dataId,
            "data-category" => $dataCategory
        ];
        $iconClass = "fas fa-trash";
        return self::button($iconClass, $url, $customClass, $customAttributes, $iconText);
    }

    /**
     * @param $url
     * @param string $title
     * @return string
     */
    public static function restoreButton($url, string $title = "Restore") {
        $customClass = ["btn-gradient-success", "restore-data"];
        $customAttributes = [
            "title" => trans($title),
        ];
        $iconClass = "fa fa-refresh";
        return self::button($iconClass, $url, $customClass, $customAttributes);
    }

    /**
     * @param $url
     * @return string
     */
    public static function trashButton($url) {
        $customClass = ["btn-gradient-danger", "trash-data"];
        $customAttributes = [
            "title" => trans("Delete Permanent"),
        ];
        $iconClass = "fa fa-times";
        return self::button($iconClass, $url, $customClass, $customAttributes);
    }

    public static function optionButton($url) {
        $customClass = ["btn-option"];
        $customAttributes = [
            "title" => trans("View Option Data"),
        ];
        $iconClass = "bi bi-gear";
        $iconText = "Options";
        return self::button($iconClass, $url, $customClass, $customAttributes, $iconText);
    }
}
