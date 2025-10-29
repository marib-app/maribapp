/**
 * @extends Factory<DepartmentNotice>
 */
class DepartmentNoticeFactory extends Factory
{
    protected $model = DepartmentNotice::class;

    public function definition(): array
    {
        $startsAt = $this->faker->dateTimeBetween('-1 day', 'now');

        return [
            'department' => $this->faker->randomElement(config('cart.departments', ['shein', 'computer', 'store', 'services'])),
            'title' => $this->faker->sentence(),
            'body' => $this->faker->paragraph(),
            'severity' => $this->faker->randomElement(['info', 'warning', 'critical']),
            'starts_at' => $startsAt,
            'ends_at' => $this->faker->optional()->dateTimeBetween('now', '+2 days'),
            'metadata' => [],
            'is_active' => true,
        ];
    }
}
