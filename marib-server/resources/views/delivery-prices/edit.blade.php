@extends('layouts.app')

@section('title', 'إدارة خدمات التوصيل')

@section('css')
    @include('delivery-prices.manager-styles')
@endsection

@section('content')
    @include('delivery-prices.manager')
@endsection





@section('scripts')
    @include('delivery-prices.manager-scripts')
@endsection