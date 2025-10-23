<?php

namespace App\Http\Controllers;

use App\Models\Service;
use App\Models\ServiceReview;
use App\Services\ResponseService;
use App\Services\ServiceAuthorizationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Throwable;

class ServiceReviewController extends Controller
{
    public function __construct(private ServiceAuthorizationService $serviceAuthorizationService)
    {
    }

    public function index(Service $service, Request $request)
    {
        try {
            $this->serviceAuthorizationService->ensureUserCanManageService(Auth::user(), $service);

            $status = $request->input('status');
            $perPage = (int) $request->input('per_page', 20);
            $page = max(1, (int) $request->input('page', 1));


            $reviewsQuery = $service->reviews()->with('user:id,name,profile')->orderByDesc('created_at');

            if ($status) {
                $reviewsQuery->where('status', $status);
            }

            $reviews = $reviewsQuery->paginate($perPage, ['*'], 'page', $page);

            $reviews->getCollection()->transform(static function (ServiceReview $review) {
                return [
                    'id'         => $review->id,
                    'rating'     => $review->rating,
                    'status'     => $review->status,
                    'review'     => $review->review,
                    'user'       => $review->user ? [
                        'id'      => $review->user->id,
                        'name'    => $review->user->name,
                        'profile' => $review->user->profile,
                    ] : null,
                    'created_at' => optional($review->created_at)->toDateTimeString(),
                ];
            });

            return response()->json([
                'rows'         => $reviews->items(),
                'total'        => $reviews->total(),
                'per_page'     => $reviews->perPage(),
                'current_page' => $reviews->currentPage(),
                'last_page'    => $reviews->lastPage(),
                
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ServiceReviewController -> index');
            return ResponseService::errorResponse();
        }
    }

    public function updateStatus(Request $request, Service $service, ServiceReview $serviceReview)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:pending,approved,rejected',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        if ($serviceReview->service_id !== $service->id) {
            abort(404);
        }

        try {
            $this->serviceAuthorizationService->ensureUserCanManageService(Auth::user(), $service);

            $serviceReview->status = $request->status;
            $serviceReview->save();

            ResponseService::successResponse('Service review status updated successfully.', $serviceReview->fresh('user:id,name,profile'));
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ServiceReviewController -> updateStatus');
            ResponseService::errorResponse();
        }
    }
}