<?php

namespace App\Services;
use App\Exceptions\ResponseServiceTestException;

use Exception;
use Illuminate\Contracts\Foundation\Application;
use Illuminate\Http\JsonResponse;
use Illuminate\Contracts\Pagination\Paginator as PaginatorContract;
use Illuminate\Http\RedirectResponse;
use Illuminate\Routing\Redirector;
use Illuminate\Support\Facades\App;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Support\MessageBag;

use Throwable;

class ResponseService
{
    /**
     * @param $permission
     * @return Application|RedirectResponse|Redirector|true
     */
    public static function noPermissionThenRedirect($permission)
    {
        if (!Auth::user()->can($permission)) {
            return redirect(route('home'))->withErrors([
                'message' => trans("You Don't have enough permissions")
            ])->send();
        }
        return true;
    }

    /**
     * @param $permission
     * @return true
     */
    public static function noPermissionThenSendJson($permission)
    {
        if (!Auth::user()->can($permission)) {
            self::errorResponse("You Don't have enough permissions");
        }
        return true;
    }

    /**
     * @param $role
     * @return Application|\Illuminate\Foundation\Application|RedirectResponse|Redirector|true
     */
    // Check user role
    public static function noRoleThenRedirect($role)
    {
        if (!Auth::user()->hasRole($role)) {
            return redirect(route('home'))->withErrors([
                'message' => trans("You Don't have enough permissions")
            ])->send();
        }
        return true;
    }

    /**
     * @param array $role
     * @return bool|Application|\Illuminate\Foundation\Application|RedirectResponse|Redirector
     */
    public static function noAnyRoleThenRedirect(array $role)
    {
        if (!Auth::user()->hasAnyRole($role)) {
            return redirect(route('home'))->withErrors([
                'message' => trans("You Don't have enough permissions")
            ])->send();
        }
        return true;
    }

    //    /**
    //     * @param $role
    //     * @return true
    //     */
    //    public static function noRoleThenSendJson($role)
    //    {
    //        if (!Auth::user()->hasRole($role)) {
    //            self::errorResponse("You Don't have enough permissions");
    //        }
    //        return true;
    //    }

    /**
     * @param $feature
     * @return RedirectResponse|true
     */
    // Check Feature
    //    public static function noFeatureThenRedirect($feature) {
    //        if (Auth::user()->school_id && !app(FeaturesService::class)->hasFeature($feature)) {
    //            return redirect()->back()->withErrors([
    //                'message' => trans('Purchase') . " " . $feature . " " . trans("to Continue using this functionality")
    //            ])->send();
    //        }
    //        return true;
    //    }
    //
    //    public static function noFeatureThenSendJson($feature) {
    //        if (Auth::user()->school_id && !app(FeaturesService::class)->hasFeature($feature)) {
    //            self::errorResponse(trans('Purchase') . " " . $feature . " " . trans("to Continue using this functionality"));
    //        }
    //        return true;
    //    }

    /**
     * If User don't have any of the permission that is specified in Array then Redirect will happen
     * @param array $permissions
     * @return RedirectResponse|true
     */
    public static function noAnyPermissionThenRedirect(array $permissions)
    {
        if (!Auth::check()) {
            return redirect()->guest(route('login'))->send();
        }

        if (!Auth::user()->canany($permissions)) {
            return redirect()->back()->withErrors([
                'message' => trans("You Don't have enough permissions")
            ])->send();
        }
        return true;
    }

    /**
     * If User don't have any of the permission that is specified in Array then Json Response will be sent
     * @param array $permissions
     * @return true
     */
    public static function noAnyPermissionThenSendJson(array $permissions)
    {

        if (!Auth::check()) {
            self::errorResponse('Unauthenticated.', null, Response::HTTP_UNAUTHORIZED);
        }

        if (!Auth::user()->canany($permissions)) {
            self::errorResponse("You Don't have enough permissions");
        }
        return true;
    }

    /**
     * @param string|null $message
     * @param null $data
     * @param array $customData
     * @param null $code
     * @return void
     */
    public static function successResponse(string|null $message = "Success", $data = null, array $customData = array(), $code = null): void
    {

        $itemsKey = 'items';

        if (array_key_exists('items_key', $customData)) {
            $customItemsKey = $customData['items_key'];

            if (is_string($customItemsKey) && $customItemsKey !== '') {
                $itemsKey = $customItemsKey;
            }

            unset($customData['items_key']);

        }

        $appendToData = [];

        if (array_key_exists('append_to_data', $customData)) {
            $candidateAppend = $customData['append_to_data'];

            if (is_array($candidateAppend)) {
                $appendToData = $candidateAppend;
            }

            unset($customData['append_to_data']);
        }

        if ($data instanceof PaginatorContract) {
            [$items, $meta, $links, $linkItems] = self::formatPaginator($data);

            $pagination = array_merge($meta, $links);
            $pagination['links'] = $linkItems;

            $data = [
                $itemsKey => $items,
                'meta' => $meta,
                'links' => $links,
                'link_items' => $linkItems,
                'pagination' => $pagination,
            ];
        }

        if (!empty($appendToData)) {
            if ($data === null) {
                $data = $appendToData;
            } elseif (is_array($data)) {
                $data = array_merge($data, $appendToData);
            } else {
                $data = array_merge([
                    $itemsKey => $data,
                ], $appendToData);
            }
        }

        $response = response()->json(array_merge([
            'error'   => false,
            'message' => trans($message),
            'data'    => $data,
            'code'    => $code ?? config('constants.RESPONSE_CODE.SUCCESS')
        ], $customData));

        self::finalizeResponse($response);
    }


    /**
     * @return array{0: array<int, mixed>, 1: array<string, mixed>, 2: array<string, mixed>, 3: array<int, array<string, mixed>>}
     */
    private static function formatPaginator(PaginatorContract $paginator): array
    {



        $paginatorArray = $paginator->toArray();

        $items = $paginatorArray['data'] ?? $paginator->items();

        if (! is_array($items)) {
            $items = $paginator->items();
        }


        $items = array_map(static function ($item) {
            if (is_array($item)) {
                return $item;
            }

            if (is_object($item) && method_exists($item, 'toArray')) {
                return $item->toArray();
            }

            return $item;
        }, $items);

        $currentPage = $paginatorArray['current_page'] ?? (method_exists($paginator, 'currentPage') ? $paginator->currentPage() : null);
        $perPage = $paginatorArray['per_page'] ?? (method_exists($paginator, 'perPage') ? $paginator->perPage() : null);
        $from = $paginatorArray['from'] ?? (method_exists($paginator, 'firstItem') ? $paginator->firstItem() : null);
        $to = $paginatorArray['to'] ?? (method_exists($paginator, 'lastItem') ? $paginator->lastItem() : null);
        $lastPage = $paginatorArray['last_page'] ?? (method_exists($paginator, 'lastPage') ? $paginator->lastPage() : null);
        $total = $paginatorArray['total'] ?? (method_exists($paginator, 'total') ? $paginator->total() : null);

        $meta = [
            'current_page' => $currentPage,
            'from' => $from,
            'last_page' => $lastPage,
            'per_page' => $perPage,
            'to' => $to,
            'total' => $total,
        ];

        if (method_exists($paginator, 'hasMorePages')) {
            $meta['has_more_pages'] = $paginator->hasMorePages();
        }

        if (method_exists($paginator, 'hasPages')) {
            $meta['has_pages'] = $paginator->hasPages();
        }

        $path = $paginatorArray['path'] ?? (method_exists($paginator, 'path') ? $paginator->path() : null);
        $firstPageUrl = null;
        $lastPageUrl = null;

        if (method_exists($paginator, 'url')) {
            $firstPageUrl = $paginator->url(1);

            if ($lastPage !== null && $lastPage >= 1) {
                $lastPageUrl = $paginator->url($lastPage);
            }
        }

        $links = [
            'first_page_url' => $paginatorArray['first_page_url'] ?? $firstPageUrl,
            'last_page_url' => $paginatorArray['last_page_url'] ?? $lastPageUrl,
            'next_page_url' => $paginatorArray['next_page_url'] ?? $paginator->nextPageUrl(),
            'prev_page_url' => $paginatorArray['prev_page_url'] ?? $paginator->previousPageUrl(),
            'path' => $path,
        ];

        $linkItems = $paginatorArray['links'] ?? [];

        if (! is_array($linkItems)) {
            $linkItems = [];
        }
        return [$items, $meta, $links, $linkItems];

    }



    /**
     * @param string $message
     * @param $url
     * @return Application|\Illuminate\Foundation\Application|RedirectResponse|Redirector
     */
    public static function successRedirectResponse(string $message = "success", $url = null)
    {
        return isset($url) ? redirect($url)->with([
            'success' => trans($message)
        ])->send() : redirect()->back()->with([
            'success' => trans($message)
        ])->send();
    }

    /**
     *
     * @param string $message - Pass the Translatable Field
     * @param null $data
     * @param string $code
     * @param null $e
     * @return void
     */
    public static function errorResponse(string $message = 'Error Occurred', $data = null, string|int $code = null, $e = null)
    {
        $response = response()->json([
            'error'   => true,
            'message' => trans($message),
            'data'    => $data,
            'code'    => $code ?? config('constants.RESPONSE_CODE.EXCEPTION_ERROR'),
            'details' => (!empty($e) && is_object($e)) ? $e->getMessage() . ' --> ' . $e->getFile() . ' At Line : ' . $e->getLine() : ''
        ]);

        self::finalizeResponse($response);
    }

    /**
     * return keyword should, must be used wherever this function is called.
     * @param string|string[] $message
     * @param $url
     * @param null $input
     * @return RedirectResponse
     */
    public static function errorRedirectResponse(string|array $message = 'Error Occurred', $url = 'back', $input = null)
    {
        return $url == "back" ? redirect()->back()->with([
            'errors' => trans($message)
        ])->withInput($input) : redirect($url)->with([
            'errors' => trans($message)
        ])->withInput($input);
    }

    /**
     * @param string $message
     * @param null $data
     * @param null $code
     * @return void
     */
    public static function warningResponse(string $message = 'Error Occurred', $data = null, $code = null)
    {
        response()->json([
            'error'   => false,
            'warning' => true,
            'code'    => $code,
            'message' => trans($message),
            'data'    => $data,
        ])->send();
        exit();
    }


    /**
     * @param string $message
     * @param null $data
     * @return void
     */
    public static function validationError(string $message = 'Error Occurred', $data = null)
    {
        self::errorResponse($message, $data, config('constants.RESPONSE_CODE.VALIDATION_ERROR'));
    }

    /**
     * @param MessageBag|array $errors
     * @return void
     */
    public static function validationErrors(MessageBag|array $errors)
    {
        if ($errors instanceof MessageBag) {
            $errors = $errors->toArray();
        }

        $response = response()->json([
            'error'  => true,
            'code'   => config('constants.RESPONSE_CODE.VALIDATION_ERROR'),
            'errors' => $errors,
        ]);

        self::finalizeResponse($response);
    }
    protected static function finalizeResponse(Response|JsonResponse $response): void
    {
        if (App::runningUnitTests()) {
            throw new ResponseServiceTestException($response);
        }

        $response->send();
        exit();
    }

    /**
     * @param string $message
     * @return void
     */
    public static function validationErrorRedirect(string $message = 'Error Occurred')
    {
        self::errorRedirectResponse(route('custom-fields.create'), $message);
        exit();
    }

    /**
     * @param Throwable|Exception $e
     * @param string $logMessage
     * @param string $responseMessage
     * @param bool $jsonResponse
     * @return void
     */
    public static function logErrorResponse(Throwable|Exception $e, string $logMessage = ' ', string $responseMessage = 'Error Occurred', bool $jsonResponse = true)
    {
        Log::error($logMessage . ' ' . $e->getMessage() . '---> ' . $e->getFile() . ' At Line : ' . $e->getLine() . "\n\n" . request()->method() . " : " . request()->fullUrl() . "\nParams : ", request()->all());
        if ($jsonResponse && config('app.debug')) {
            self::errorResponse($responseMessage, null, null, $e);
        }
    }

    /**
     * @param $e
     * @param string $logMessage
     * @param string $responseMessage
     * @param bool $jsonResponse
     */
    public static function logErrorRedirect($e, string $logMessage = ' ', string $responseMessage = 'Error Occurred', bool $jsonResponse = true)
    {
        Log::error($logMessage . ' ' . $e->getMessage() . '---> ' . $e->getFile() . ' At Line : ' . $e->getLine());
        if ($jsonResponse && config('app.debug')) {
            throw $e;
        }
    }
}
