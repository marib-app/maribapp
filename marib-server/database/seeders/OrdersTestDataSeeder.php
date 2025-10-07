<?php

namespace Database\Seeders;

use App\Models\Item;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Spatie\Permission\Models\Role;
use App\Support\OrderNumberGenerator;

class OrdersTestDataSeeder extends Seeder
{
    /**
     * تشغيل البيانات التجريبية.
     */
    public function run(): void
    {
        // التأكد من وجود دور User
        $userRole = Role::firstOrCreate(['name' => 'User']);

        // إنشاء مستخدمين (عملاء)
        $customers = [];
        for ($i = 1; $i <= 3; $i++) {
            $customer = User::create([
                'name' => "عميل تجريبي $i",
                'email' => "customer$i@test.com",
                'password' => Hash::make('password123'),
                'mobile' => "123456789$i",
                'type' => 'email',
                'fcm_id' => Str::random(20),
                'account_type' => 1, // عميل
            ]);
            $customer->assignRole('User');
            $customers[] = $customer;
        }

        // إنشاء مستخدمين (تجار)
        $sellers = [];
        for ($i = 1; $i <= 2; $i++) {
            $seller = User::create([
                'name' => "تاجر تجريبي $i",
                'email' => "seller$i@test.com",
                'password' => Hash::make('password123'),
                'mobile' => "987654321$i",
                'type' => 'email',
                'fcm_id' => Str::random(20),
                'account_type' => 2, // تاجر
            ]);
            $seller->assignRole('User');
            $sellers[] = $seller;
        }

        // إنشاء منتجات
        $items = [];
        $categories = [1, 2, 3]; // تأكد من وجود هذه الفئات في قاعدة البيانات
        $itemNames = [
            'لابتوب HP',
            'جوال سامسونج',
            'ساعة ذكية',
            'سماعات بلوتوث',
            'شاحن متنقل'
        ];

        foreach ($sellers as $seller) {
            foreach ($itemNames as $index => $name) {
                $slug = Str::slug($name . '-' . Str::random(6));
                $items[] = Item::create([
                    'name' => $name,
                    'category_id' => $categories[array_rand($categories)],
                    'price' => rand(100, 1000),
                    'description' => "وصف تجريبي للمنتج $name",
                    'user_id' => $seller->id,
                    'status' => 'approved',
                    'latitude' => '24.7136',
                    'longitude' => '46.6753',
                    'address' => 'الرياض، المملكة العربية السعودية',
                    'contact' => $seller->mobile,
                    'country' => 'السعودية',
                    'city' => 'الرياض',
                    'show_only_to_premium' => false,
                    'slug' => $slug,
                ]);
            }
        }

        // إنشاء طلبات بحالات مختلفة
        $orderStatuses = [

            Order::STATUS_PENDING,
            Order::STATUS_CONFIRMED,
            Order::STATUS_PROCESSING,
            Order::STATUS_PREPARING,
            Order::STATUS_READY_FOR_DELIVERY,
            Order::STATUS_OUT_FOR_DELIVERY,
            Order::STATUS_DELIVERED,
            Order::STATUS_FAILED,
            Order::STATUS_CANCELED,
        ];
        $statusProgressions = [
            Order::STATUS_PENDING => [Order::STATUS_PENDING],
            Order::STATUS_CONFIRMED => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED],
            Order::STATUS_PROCESSING => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED, Order::STATUS_PROCESSING],
            Order::STATUS_PREPARING => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED, Order::STATUS_PROCESSING, Order::STATUS_PREPARING],
            Order::STATUS_READY_FOR_DELIVERY => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED, Order::STATUS_PROCESSING, Order::STATUS_PREPARING, Order::STATUS_READY_FOR_DELIVERY],
            Order::STATUS_OUT_FOR_DELIVERY => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED, Order::STATUS_PROCESSING, Order::STATUS_PREPARING, Order::STATUS_READY_FOR_DELIVERY, Order::STATUS_OUT_FOR_DELIVERY],
            Order::STATUS_DELIVERED => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED, Order::STATUS_PROCESSING, Order::STATUS_PREPARING, Order::STATUS_READY_FOR_DELIVERY, Order::STATUS_OUT_FOR_DELIVERY, Order::STATUS_DELIVERED],
            Order::STATUS_FAILED => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED, Order::STATUS_PROCESSING, Order::STATUS_FAILED],
            Order::STATUS_CANCELED => [Order::STATUS_PENDING, Order::STATUS_CONFIRMED, Order::STATUS_CANCELED],


        ];
        
        $paymentMethods = ['cash', 'card', 'bank_transfer'];
        $paymentStatuses = ['pending', 'paid', 'failed'];

        foreach ($customers as $customer) {
            // إنشاء 2-4 طلبات لكل عميل
            $numOrders = rand(2, 4);
            
            for ($i = 0; $i < $numOrders; $i++) {
                // اختيار تاجر عشوائي
                $seller = $sellers[array_rand($sellers)];
                
                // اختيار 1-3 منتجات عشوائية للطلب
                $orderItems = array_rand($items, rand(1, 3));
                if (!is_array($orderItems)) {
                    $orderItems = [$orderItems];
                }

                $totalAmount = 0;
                $orderItemsData = [];

                foreach ($orderItems as $itemIndex) {
                    $item = $items[$itemIndex];
                    $quantity = rand(1, 3);
                    $price = $item->price;
                    $subtotal = $price * $quantity;
                    $totalAmount += $subtotal;

                    $orderItemsData[] = [
                        'item_id' => $item->id,
                        'item_name' => $item->name,
                        'price' => $price,
                        'quantity' => $quantity,
                        'subtotal' => $subtotal,
                    ];
                }

                $taxAmount = $totalAmount * 0.15; // 15% ضريبة
                $finalAmount = $totalAmount + $taxAmount;

                // إنشاء الطلب

                $departments = ['shein', 'computer', 'general'];
                $department = $departments[array_rand($departments)];
                $createdAt = now();
                $finalStatus = $orderStatuses[array_rand($orderStatuses)];
                $statusSequence = $statusProgressions[$finalStatus];
                $statusHistory = [];
                $statusTimestamps = [];

                foreach ($statusSequence as $index => $status) {
                    $timestamp = $createdAt->copy()->addMinutes($index * 10);
                    $statusHistory[] = [
                        'status' => $status,
                        'recorded_at' => $timestamp->toIso8601String(),
                        'user_id' => $index === 0 ? $customer->id : $seller->id,
                        'comment' => $index === 0
                            ? 'تم إنشاء الطلب تجريبياً'
                            : "تم تحديث حالة الطلب إلى {$status}",

                        'display' => Order::statusTimelineMessage($status),
                        'icon' => Order::statusIcon($status),

                    ];
                    $statusTimestamps[$status] = $timestamp->toIso8601String();
                }


                $order = Order::create([
                    'user_id' => $customer->id,
                    'seller_id' => $seller->id,
                    'department' => $department,
                    'order_number' => OrderNumberGenerator::provisional(),
                    'invoice_no' => 'INV-' . Str::upper(Str::random(10)),
                    'total_amount' => $totalAmount,
                    'tax_amount' => $taxAmount,
                    'discount_amount' => 0,
                    'final_amount' => $finalAmount,
                    'payment_method' => $paymentMethods[array_rand($paymentMethods)],
                    'payment_status' => $paymentStatuses[array_rand($paymentStatuses)],
                    'order_status' => $finalStatus,
                    'shipping_address' => "عنوان الشحن التجريبي للعميل {$customer->name}",
                    'billing_address' => "عنوان الفواتير التجريبي للعميل {$customer->name}",
                    'address_snapshot' => [
                        'label' => "عنوان {$customer->name}",
                        'phone' => $customer->mobile,
                        'street' => 'شارع رئيسي',
                        'building' => 'مبنى 1',
                    ],

                    'notes' => 'ملاحظات تجريبية للطلب',
                    'completed_at' => rand(0, 1) ? now() : null,
                    'delivery_payment_timing' => 'pay_on_delivery',
                    'delivery_payment_status' => 'due_on_delivery',
                    'delivery_online_payable' => 0,
                    'delivery_cod_fee' => 5,
                    'delivery_cod_due' => 5,
                    'status_history' => $statusHistory,
                    'delivery_price' => 15,
                    'delivery_price_breakdown' => [
                        ['type' => 'base', 'amount' => 15],
                    ],
                    'delivery_fee' => 15,
                    'delivery_total' => 15,
                    'delivery_surcharge' => 0,
                    'delivery_discount' => 0,
                    'delivery_collected_amount' => 0,
                    'payment_due_at' => $createdAt,
                    'last_quoted_at' => $createdAt,
                    'status_timestamps' => $statusTimestamps,


                ]);
                
                $order = $order->refreshOrderNumber();

                // إنشاء عناصر الطلب
                foreach ($orderItemsData as $itemData) {
                    OrderItem::create([
                        'order_id' => $order->id,
                        'item_id' => $itemData['item_id'],
                        'variant_id' => null,
                        'item_name' => $itemData['item_name'],
                        'price' => $itemData['price'],
                        'quantity' => $itemData['quantity'],
                        'subtotal' => $itemData['subtotal'],
                        'options' => ['gift_wrap' => false],
                        'attributes' => ['color' => 'أحمر'],
                        'weight_grams' => 0,
                        'weight_kg' => 0,


                    ]);
                }

                // إنشاء سجل الطلب
                $previousStatus = null;
                foreach ($statusSequence as $index => $statusStep) {
                    OrderHistory::create([
                        'order_id' => $order->id,
                        'user_id' => $index === 0 ? $customer->id : $seller->id,
                        'status_from' => $previousStatus,
                        'status_to' => $statusStep,
                        'comment' => $index === 0 ? 'تم إنشاء الطلب' : "تم تغيير حالة الطلب إلى {$statusStep}",
                        'created_at' => $createdAt->copy()->addMinutes($index * 10),
                    ]);
                    $previousStatus = $statusStep;
                }
            }
        }
    }
} 