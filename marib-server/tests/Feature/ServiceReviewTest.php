<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\ServiceReview;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ServiceReviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_service_review(): void
    {
        $user = User::factory()->create();
        $category = $this->createCategory();
        $service = $this->createService($category);
        $this->createServiceRequest($service, $user, 'approved');

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/add-service-review', [
            'service_id' => $service->id,
            'rating' => 4,
            'review' => 'خدمة ممتازة',
        ]);

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'message' => 'Service review submitted successfully.',
        ]);

        $this->assertDatabaseHas('service_reviews', [
            'service_id' => $service->id,
            'user_id' => $user->id,
            'rating' => 4,
            'review' => 'خدمة ممتازة',
            'status' => ServiceReview::STATUS_PENDING,
        ]);
    }

    public function test_user_cannot_submit_duplicate_service_review(): void
    {
        $user = User::factory()->create();
        $category = $this->createCategory();
        $service = $this->createService($category);
        $this->createServiceRequest($service, $user, 'approved');

        ServiceReview::create([
            'service_id' => $service->id,
            'user_id' => $user->id,
            'rating' => 5,
            'review' => 'تقييم سابق',
            'status' => ServiceReview::STATUS_PENDING,
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/add-service-review', [
            'service_id' => $service->id,
            'rating' => 3,
            'review' => 'محاولة أخرى',
        ]);

        $response->assertOk();
        $response->assertJson([
            'error' => true,
            'message' => 'You have already reviewed this service.',
        ]);
    }

    public function test_can_fetch_service_reviews(): void
    {
        $category = $this->createCategory();
        $service = $this->createService($category);

        $firstUser = User::factory()->create();
        $secondUser = User::factory()->create();

        $this->createServiceRequest($service, $firstUser, 'approved');
        $this->createServiceRequest($service, $secondUser, 'approved');

        $firstReview = ServiceReview::create([
            'service_id' => $service->id,
            'user_id' => $firstUser->id,
            'rating' => 5,
            'review' => 'رائع للغاية',
            'status' => ServiceReview::STATUS_APPROVED,
        ]);

        $secondReview = ServiceReview::create([
            'service_id' => $service->id,
            'user_id' => $secondUser->id,
            'rating' => 3,
            'review' => 'مقبول',
            'status' => ServiceReview::STATUS_APPROVED,
        ]);

        // Pending review should not appear in the default listing
        ServiceReview::create([
            'service_id' => $service->id,
            'user_id' => User::factory()->create()->id,
            'rating' => 4,
            'review' => 'بانتظار الموافقة',
            'status' => ServiceReview::STATUS_PENDING,
        ]);

        $response = $this->getJson('/api/service-reviews?service_id=' . $service->id);

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [
                'service_id' => $service->id,
                'total_reviews' => 2,
            ],
        ]);

        $this->assertEquals(4.0, $response->json('data.average_rating'));

        $returnedIds = collect($response->json('data.reviews'))->pluck('id')->all();
        $this->assertEqualsCanonicalizing([
            $firstReview->id,
            $secondReview->id,
        ], $returnedIds);
    }

    private function createCategory(string $name = 'Services Category', string $slug = 'services-category'): Category
    {
        return Category::create([
            'name' => $name,
            'image' => 'categories/example.jpg',
            'status' => true,
            'slug' => $slug,
        ]);
    }

    private function createService(Category $category, string $title = 'Test Service'): Service
    {
        return Service::create([
            'category_id' => $category->id,
            'title' => $title,
            'slug' => Str::slug($title) . '-' . uniqid(),
            'description' => 'Service description',
            'status' => true,
            'is_main' => true,
            'service_type' => 'standard',
            'views' => 0,
            'is_paid' => false,
            'has_custom_fields' => false,
            'direct_to_user' => false,
        ]);
    }

    private function createServiceRequest(Service $service, User $customer, string $status): ServiceRequest
    {
        $request = new ServiceRequest();
        $request->service_id = $service->id;
        $request->user_id = $customer->id;
        $request->status = $status;
        $request->payload = ['field' => 'value'];
        $request->save();

        return $request;
    }
}