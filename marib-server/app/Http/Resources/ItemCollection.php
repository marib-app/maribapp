<?php

namespace App\Http\Resources;
use App\Services\DepartmentAdvertiserService;
use App\Services\DepartmentPolicyService;

use Illuminate\Contracts\Support\Arrayable;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;
use Illuminate\Pagination\AbstractPaginator;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use JsonSerializable;
use Throwable;
use function collect;
use App\Services\DepartmentReportService;



class ItemCollection extends ResourceCollection {
    /**
     * Transform the resource into an array.
     *
     * @param Request $request
     * @return array|Arrayable|JsonSerializable
     * @throws Throwable
     */
    public function toArray(Request $request) {
        try {
            $response = [];
            $departmentAdvertiserService = app(DepartmentAdvertiserService::class);
            $departmentPolicyService = app(DepartmentPolicyService::class);


            $currentUserId = Auth::id();
            foreach ($this->collection as $key => $collection) {
                
                /* NOTE : This code can be improved */
                $response[$key] = $collection->toArray();
                $originalImageUrl = $collection->image;
                $response[$key]['thumbnail_url'] = $collection->thumbnail_url ?? $originalImageUrl;
                $response[$key]['detail_image_url'] = $collection->detail_image_url ?? $originalImageUrl;
                $response[$key]['thumbnail_fallback_url'] = $originalImageUrl;
                $response[$key]['detail_image_fallback_url'] = $originalImageUrl;
                unset($response[$key]['image']);

                if (! empty($response[$key]['gallery_images']) && is_array($response[$key]['gallery_images'])) {
                    $response[$key]['gallery_images'] = collect($response[$key]['gallery_images'])->map(static function (array $galleryImage) {
                        $originalGalleryImage = $galleryImage['image'] ?? null;
                        $galleryImage['thumbnail_url'] = $galleryImage['thumbnail_url'] ?? $originalGalleryImage;
                        $galleryImage['detail_image_url'] = $galleryImage['detail_image_url'] ?? $originalGalleryImage;
                        $galleryImage['thumbnail_fallback_url'] = $originalGalleryImage;
                        $galleryImage['detail_image_fallback_url'] = $originalGalleryImage;
                        unset($galleryImage['image']);

                        return $galleryImage;
                    })->all();
                }

                $response[$key]['product_link'] = $collection->product_link;
                $response[$key]['review_link'] = $collection->review_link;
                $response[$key]['video_link'] = $collection->video_link;
                $response[$key]['base_price'] = (float) ($collection->price ?? 0.0);
                $response[$key]['final_price'] = $collection->calculateDiscountedPrice();
                $response[$key]['discount'] = $collection->discount_snapshot;

                if ($collection->status == "approved" && $collection->relationLoaded('featured_items')) {
                    $response[$key]['is_feature'] = count($collection->featured_items) > 0;
                }else{
                    $response[$key]['is_feature'] = false;
                }


                /*** Favourites ***/
                if ($collection->relationLoaded('favourites')) {
                    $response[$key]['total_likes'] = $collection->favourites->count();
                    if (Auth::check()) {
//                        $response[$key]['is_liked'] = $collection->favourites->where(['item_id' => $collection->id, 'user_id' => Auth::user()->id])->count() > 0;
                        $response[$key]['is_liked'] = $collection->favourites->where('item_id', $collection->id)->where('user_id', Auth::user()->id)->count() > 0;
                    } else {
                        $response[$key]['is_liked'] = false;
                    }
                }
                if ($collection->relationLoaded('user') && !is_null($collection->user)) {

                    $response[$key]['user'] = $collection->user;
                    $response[$key]['user']['reviews_count'] = $collection->user->sellerReview()->count();
                    $response[$key]['user']['average_rating'] = $collection->user->sellerReview->avg('ratings');
                    if ($collection->user->show_personal_details == 0) {
                        $response[$key]['user']['mobile'] = '';
                        $response[$key]['user']['country_code'] = '';
                        $response[$key]['user']['email'] = '';

                    }
                }
                /*** Custom Fields ***/
                if ($collection->relationLoaded('item_custom_field_values')) {
                    $response[$key]['custom_fields'] = [];
                    foreach ($collection->item_custom_field_values as $key2 => $customFieldValue) {
                        $tempRow = [];
                        if ($customFieldValue->relationLoaded('custom_field')) {
                            if (!empty($customFieldValue->custom_field)) {
                                $tempRow = $customFieldValue->custom_field->toArray();

                                if ($customFieldValue->custom_field->type == "fileinput") {
                                    if (!is_array($customFieldValue->value)) {
                                        $tempRow['value'] = !empty($customFieldValue->value) ? [url(Storage::url($customFieldValue->value))] : [];
                                    } else {
                                        $tempRow['value'] = null;
                                    }
                                } elseif ($customFieldValue->custom_field->type == "color") {
                                    // Handle color field type - decode JSON values
                                    if (!empty($customFieldValue->value)) {
                                        // Check if value is already an array or needs JSON decoding
                                        if (is_string($customFieldValue->value)) {
                                            $decodedValue = json_decode($customFieldValue->value, true);
                                            $tempRow['value'] = (json_last_error() === JSON_ERROR_NONE && is_array($decodedValue)) ? $decodedValue : [];
                                        } elseif (is_array($customFieldValue->value)) {
                                            $tempRow['value'] = $customFieldValue->value;
                                        } else {
                                            $tempRow['value'] = [];
                                        }
                                    } else {
                                        $tempRow['value'] = [];
                                    }
                                } else {
                                    $tempRow['value'] = $customFieldValue->value ?? [];
                                }

                                $tempRow['custom_field_value'] = !empty($customFieldValue) ? $customFieldValue->toArray() : (object)[];
                            }

                            unset($tempRow['custom_field_value']['custom_field']);

                            $response[$key]['custom_fields'][$key2] = $tempRow;
                        }
                    }

                    unset($response[$key]['item_custom_field_values']);
                }


                /*** Item Offers ***/
                if ($collection->relationLoaded('item_offers') && Auth::check()) {
                    $response[$key]['is_already_offered'] = $collection->item_offers->where('item_id', $collection->id)->where('buyer_id', Auth::user()->id)->count() > 0;
                } else {
                    $response[$key]['is_already_offered'] = false;
                }

                /*** User Reports ***/
                if ($collection->relationLoaded('user_reports') && Auth::check()) {
                    $response[$key]['is_already_reported'] = $collection->user_reports->where('user_id', Auth::user()->id)->count() > 0;
                } else {
                    $response[$key]['is_already_reported'] = false;
                }

                if (Auth::check()) {
                    $response[$key]['is_purchased'] = $collection->sold_to==Auth::user()->id ? 1 : 0;
                } else {
                    $response[$key]['is_purchased'] = 0;
                }

                $department = $departmentAdvertiserService->resolveDepartmentForItem($collection);
                if ($department !== null) {
                    $response[$key]['department'] = $department;
                }
                if ($department === DepartmentReportService::DEPARTMENT_SHEIN) {

                    
                    $productLink = $collection->product_link;
                    $response[$key]['tips'] = [
                        'product_link' => $productLink,
                        'actions' => $productLink ? [[
                            'type' => 'open_url',
                            'label' => __('Verify Product'),
                            'url' => $productLink,
                        ]] : [],
                    ];
                }

                if ($department === DepartmentReportService::DEPARTMENT_SHEIN || $department === DepartmentReportService::DEPARTMENT_COMPUTER) {
                    $policy = $departmentPolicyService->policyFor($department);
                    $policyText = $policy['return_policy_text'] ?? null;

                    if ($policyText !== null && $policyText !== '') {
                        if (! isset($response[$key]['tips'])) {
                            $response[$key]['tips'] = [
                                'actions' => [],
                            ];
                        }

                        $response[$key]['tips']['return_policy_text'] = $policyText;
                    }
                }

                if ($collection->relationLoaded('store')) {
                    $storePolicyText = $this->buildStorePolicySummary($collection->store);
                    if ($storePolicyText !== null) {
                        if (! isset($response[$key]['tips'])) {
                            $response[$key]['tips'] = [
                                'actions' => [],
                            ];
                        }
                        $response[$key]['tips']['return_policy_text'] = $storePolicyText;
                    }
                }

                if ($department) {
                    $advertiser = $departmentAdvertiserService->getAdvertiser($department);

                    if (! empty($advertiser)) {
                        $response[$key]['department_advertiser'] = array_merge($advertiser, [
                            'department' => $department,
                        ]);

                        $isOwner = $currentUserId !== null && (int) $collection->user_id === (int) $currentUserId;

                        if (! $isOwner) {
                            $response[$key]['owner_user'] = $response[$key]['user'] ?? null;

                            $response[$key]['contact'] = $advertiser['contact_number'] ?? '';
                            $response[$key]['address'] = $advertiser['location'] ?? '';

                            $updatedUser = $response[$key]['user'] ?? [];
                            $updatedUser['name'] = $advertiser['name'] ?? '';
                            $updatedUser['profile'] = $advertiser['image'] ?? null;
                            $updatedUser['mobile'] = $advertiser['message_number'] ?? '';

                            $response[$key]['user'] = $updatedUser;
                        }
                    }
                }

                $response[$key]['requires_selection'] = false;
                $response[$key]['option_groups'] = [];
                $response[$key]['available_values'] = [];
                $response[$key]['variants_summary'] = [];

                if ($collection->sell_via_cart) {
                    $optionGroups = $collection->relationLoaded('option_groups')
                        ? $collection->getRelation('option_groups')
                        : collect();

                    $sortedGroups = $optionGroups->sortBy('sort_order')->values();

                    $response[$key]['option_groups'] = $sortedGroups->map(static function ($group) {
                        $values = $group->relationLoaded('option_values')
                            ? $group->getRelation('option_values')
                            : collect();

                        $sortedValues = $values->sortBy('sort_order')->values()->map(static function ($value) {
                            return [
                                'id' => $value->id,
                                'label' => $value->label,
                                'is_available' => (bool) $value->is_available,
                                'sort_order' => (int) $value->sort_order,
                            ];
                        });

                        return [
                            'id' => $group->id,
                            'name' => $group->name,
                            'is_required' => (bool) $group->is_required,
                            'sort_order' => (int) $group->sort_order,
                            'values' => $sortedValues->all(),
                        ];
                    })->all();

                    $response[$key]['available_values'] = $sortedGroups
                        ->flatMap(static function ($group) {
                            $values = $group->relationLoaded('option_values')
                                ? $group->getRelation('option_values')
                                : collect();

                            return $values->sortBy('sort_order')->values()->map(static function ($value) use ($group) {
                                return [
                                    'id' => $value->id,
                                    'option_group_id' => $group->id,
                                    'label' => $value->label,
                                    'is_available' => (bool) $value->is_available,
                                    'sort_order' => (int) $value->sort_order,
                                ];
                            });
                        })
                        ->values()
                        ->all();

                    $variants = $collection->relationLoaded('item_variants')
                        ? $collection->getRelation('item_variants')
                        : collect();

                    $response[$key]['variants_summary'] = $variants
                        ->sortBy('id')
                        ->values()
                        ->map(static function ($variant) {
                            return [
                                'id' => $variant->id,
                                'sku' => $variant->sku,
                                'price' => $variant->price,
                                'weight' => $variant->weight,
                                'stock' => $variant->stock,
                                'option_value_ids' => $variant->option_value_ids ?? [],
                            ];
                        })
                        ->all();

                    $requiresSelection = (bool) $collection->requires_selection;
                    if (! $requiresSelection) {
                        $requiresSelection = $sortedGroups->contains(static function ($group) {
                            return (bool) $group->is_required;
                        });
                    }

                    $response[$key]['requires_selection'] = $requiresSelection && $collection->sell_via_cart;
                }


            }
            $featuredRows = [];
            $normalRows = [];

            foreach ($response as $key => $value) {
                // ... (Your existing code here)
                // Extracting is_feature condition and processing accordingly
                if ($value['is_feature']) {
                    $featuredRows[] = $value;
                } else {
                    $normalRows[] = $value;
                }
            }


            // Merge the featured rows first and then the normal rows
            $response = array_merge($featuredRows, $normalRows);

            if ($this->resource instanceof AbstractPaginator) {
                //If the resource has a paginated collection then we need to copy the pagination related params and actual item details data will be copied to data params
                return [
                    ...$this->resource->toArray(),
                    'data' => $response
                ];
            }

            return $response;


        } catch (Throwable $th) {
            throw $th;
        }
    }

    private function buildStorePolicySummary($store): ?string
    {
        if ($store === null) {
            return null;
        }

        $policies = $store->relationLoaded('policies')
            ? $store->policies
            : $store->policies()->where('is_active', true)->get();

        if ($policies === null) {
            return null;
        }

        $lines = $policies->filter(static function ($policy) {
            return (bool) $policy->is_active && trim((string) $policy->content) !== '';
        })->sortBy(static function ($policy) {
            return $policy->display_order ?? 0;
        })->map(static function ($policy) {
            $title = trim((string) ($policy->title ?? ''));
            $content = trim((string) $policy->content);
            if ($content === '') {
                return null;
            }
            return $title !== '' ? "{$title}: {$content}" : $content;
        })->filter()->values();

        if ($lines->isEmpty()) {
            return null;
        }

        return $lines->map(static fn ($line) => '• ' . $line)->implode("\n");
    }
}
