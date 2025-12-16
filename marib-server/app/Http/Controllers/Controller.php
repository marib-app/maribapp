<?php

namespace App\Http\Controllers;

use App\Models\ContactUs;
use App\Models\Item;
use App\Models\Service;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use App\Services\ResponseService;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Bus\DispatchesJobs;
use Illuminate\Foundation\Validation\ValidatesRequests;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Session;
use Throwable;

/*Create Method which are common across the system*/

class Controller extends BaseController {
    use AuthorizesRequests, DispatchesJobs, ValidatesRequests;

    public function changeRowOrder(Request $request) {
        try {
            $request->validate([
                'data'   => 'required|array',
                'table'  => 'required|string',
                'column' => 'nullable',
            ]);
            $column = $request->column ?? "sequence";

            $data = [];
            foreach ($request->data as $index => $row) {
                $data[] = [
                    'id'            => $row['id'],
                    (string)$column => $index
                ];
            }
            DB::table($request->table)->upsert($data, ['id'], [(string)$column]);
            ResponseService::successResponse("Order Changed Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th);
            ResponseService::errorResponse();
        }
    }

    public function changeStatus(Request $request) {
        try {
            $request->validate([
                'id'     => 'required|numeric',
                'status' => 'required|boolean',
                'table'  => 'required|string',
                'column' => 'nullable',
            ]);
            $column = $request->column ?? "status";
            $isActive = (bool) $request->status;

            //Special case for deleted_at column
            if ($column == "deleted_at") {
                //If status is active then deleted_At will be empty otherwise it will have the current time
                $request->status = ($request->status) ? null : now();
            }
            DB::table($request->table)->where('id', $request->id)->update([(string)$column => $request->status]);
            $this->notifyStatusChange((string)$request->table, (string)$column, (int)$request->id, $isActive);
            ResponseService::successResponse("Status Updated Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th);
            ResponseService::errorResponse();
        }

    }

    private function notifyStatusChange(string $table, string $column, int $id, bool $isActive): void
    {
        try {
            if ($table === 'items') {
                $item = Item::withTrashed()->find($id);

                if (empty($item?->user_id)) {
                    return;
                }

                $tokens = $this->resolveUserTokens($item->user_id);
                if ($tokens === []) {
                    return;
                }

                $statusSlug = $isActive ? 'active' : 'blocked';
                $title = $isActive ? 'تم إعادة تفعيل إعلانك' : 'تم حظر إعلانك';
                $body = $isActive
                    ? 'تم إعادة تفعيل إعلانك بعد مراجعة البلاغ.'
                    : 'تم حظر الإعلان أو الخدمة الخاصة بك نتيجة لتلقينا بلاغ معين.';

                NotificationService::sendFcmNotification($tokens, $title, $body, 'item-status', [
                    'entity'    => 'item-status',
                    'entity_id' => $item->id . '-' . $statusSlug,
                    'status'    => $statusSlug,
                    'item_id'   => $item->id,
                    'active'    => $isActive,
                ]);

                return;
            }

            if ($table === 'users' && $column === 'deleted_at') {
                $user = User::withTrashed()->find($id);

                if (empty($user)) {
                    return;
                }

                $tokens = $this->resolveUserTokens($user->id);
                if ($tokens === []) {
                    return;
                }

                $statusSlug = $isActive ? 'active' : 'blocked';
                $title = $isActive ? 'تم إعادة تفعيل حسابك' : 'تم حظر حسابك';
                $body = $isActive
                    ? 'تم إعادة تفعيل وصولك إلى التطبيق بعد مراجعة البلاغ.'
                    : 'تم حظر وصولك إلى التطبيق نتيجة بلاغ معين.';

                NotificationService::sendFcmNotification($tokens, $title, $body, 'account-status', [
                    'entity'    => 'user-status',
                    'entity_id' => $user->id . '-' . $statusSlug,
                    'status'    => $statusSlug,
                    'user_id'   => $user->id,
                    'active'    => $isActive,
                ]);

                return;
            }

            if ($table === 'services') {
                $service = Service::find($id);

                if (empty($service?->owner_id)) {
                    return;
                }

                $tokens = $this->resolveUserTokens($service->owner_id);
                if ($tokens === []) {
                    return;
                }

                $statusSlug = $isActive ? 'active' : 'blocked';
                $title = $isActive ? 'تم إعادة تفعيل خدمتك' : 'تم حظر خدمتك';
                $body = $isActive
                    ? 'تم إعادة تفعيل خدمتك بعد مراجعة البلاغ.'
                    : 'تم حظر الخدمة الخاصة بك نتيجة لتلقينا بلاغ معين.';

                NotificationService::sendFcmNotification($tokens, $title, $body, 'service-status', [
                    'entity'    => 'service-status',
                    'entity_id' => $service->id . '-' . $statusSlug,
                    'status'    => $statusSlug,
                    'service_id'=> $service->id,
                    'active'    => $isActive,
                ]);
            }
        } catch (Throwable $exception) {
            Log::warning('changeStatus: failed to send status notification', [
                'table'  => $table,
                'column' => $column,
                'id'     => $id,
                'active' => $isActive,
                'error'  => $exception->getMessage(),
            ]);
        }
    }

    private function resolveUserTokens(int $userId): array
    {
        return UserFcmToken::where('user_id', $userId)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();
    }

    public function readLanguageFile() {
        try {
            //    https://medium.com/@serhii.matrunchyk/using-laravel-localization-with-javascript-and-vuejs-23064d0c210e
            header('Content-Type: text/javascript');
//        $labels = Cache::remember('lang.js', 3600, static function () {
//            $lang = app()->getLocale();
            $lang = Session::get('language');
//            $lang = app()->getLocale();
            if (is_object($lang)) {
                $test = $lang->code ?? $lang->locale ?? 'en';
            } elseif (is_array($lang)) {
                $test = $lang['code'] ?? ($lang['locale'] ?? 'en');
            } elseif (is_string($lang) && $lang !== '') {
                $test = $lang;
            } else {
                $test = 'en';
            }
            
            
            $files = resource_path('lang/' . $test . '.json');
//            return File::get($files);
//        });]
            echo('window.languageLabels = ' . File::get($files));
            http_response_code(200);
            exit();
        } catch (Throwable $th) {
            ResponseService::errorResponse($th);
        }
    }

    public function contactUsUIndex() {
        return view('contact-us');
    }

    public function contactUsShow(Request $request) {
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->input('sort', 'id');
        $order = $request->order ?? 'DESC';

        $sql = ContactUs::orderBy($sort, $order);

        if ($sort !== 'created_at') {
            $sql->orderBy('created_at', 'desc');
        }

        if (!empty($_GET['search'])) {
            $search = $_GET['search'];
            $sql->where('id', 'LIKE', "%$search%")
                ->orwhere('name', 'LIKE', "%$search%")
                ->orwhere('subject', 'LIKE', "%$search%")
                ->orwhere('message', 'LIKE', "%$search%");
        }
        $total = $sql->count();
        $sql->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        foreach ($result as $row) {
            $rows[] = $row->toArray();
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);
    }

}
