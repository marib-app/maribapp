<?php

namespace App\Http\Controllers;

use App\Services\CategoryCloneService;
use App\Services\ResponseService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Throwable;

class SectionCategoryCloneController extends Controller
{
    public function __construct(private readonly CategoryCloneService $categoryCloneService)
    {
    }

    public function __invoke(Request $request, string $section): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('category-create');

        try {
            $result = $this->categoryCloneService->clonePublicAdsToSection($section);

            $message = __('Categories synchronized successfully (:created new, :skipped skipped, :attached fields linked)', [
                'created' => $result['created_categories'],
                'skipped' => $result['skipped_categories'],
                'attached' => $result['attached_fields'],
            ]);

            return redirect()->back()->with('success', $message);
        } catch (Throwable $th) {
            ResponseService::logErrorRedirect($th, 'SectionCategoryCloneController -> __invoke');

            $errorMessage = __('Unable to synchronize categories. Please check the logs for more details.');

            return redirect()->back()->with('errors', $errorMessage);
        }
    }
}